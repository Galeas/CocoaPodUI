//
//  PodsManagementViewController.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 01.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//
//Copyright (c) 2014 Yevgeniy Branitsky (Kratko)
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

#import "PodsManagementViewController.h"
#import "PodEditController.h"
#import "PodsOverlayController.h"
#import "PodItem.h"
#import "JMModalOverlay.h"

#import "NSObject+IDEKit.h"

NSString *const kUserDidDeleteAllPods = @"CococaPodUI:UserDidDeleteAllPods";

typedef NS_ENUM(NSUInteger, ProjectFileType) {
    XCodeProject,
    XCodeWorkspace
};

@interface PodsManagementViewController () <NSTableViewDelegate, JMModalOverlayDelegate, NSFileManagerDelegate, PodEdtitionDelegate>

@property (copy) NSString *path;
@property (strong, nonatomic) JMModalOverlay *overlay;
@property (strong, nonatomic) PodsOverlayController *overlayController;
@property (strong, nonatomic) PodEditController *editController;

@property (strong, nonatomic) NSString *platformName;
@property (strong, nonatomic) NSString *platformVersion;
@property (readonly) NSArray *platformVersions;
@property (assign, nonatomic) BOOL changed;
@property (assign, nonatomic) BOOL needReopenWorkspace;
@property (assign, nonatomic) BOOL installationSucceded;
@property (copy) NSError *installationError;

@property (strong, nonatomic) NSMutableString *podfileText;
@property (strong) IBOutlet NSArrayController *installedArrayController;
@property (strong) IBOutlet NSArrayController *availableArrayController;
@property (weak) IBOutlet NSTableView *installedTable;
@property (weak) IBOutlet NSTableView *availableTable;

- (IBAction)loadPodInfo:(id)sender;
- (IBAction)addPod:(id)sender;
- (IBAction)deletePod:(id)sender;
- (IBAction)saveAndInstallAction:(id)sender;
- (IBAction)closeAction:(id)sender;
- (IBAction)editPod:(id)sender;
- (IBAction)deleteAllPods:(id)sender;
@end

@implementation PodsManagementViewController

- (id)init
{
    self = [super initWithNibName:@"PodsManagementViewController" bundle:[NSBundle bundleForClass:[self class]]];
    [self setInstalledPods:[NSMutableArray array]];
    [[NSFileManager defaultManager] setDelegate:self];
    return self;
}

- (void)loadView
{
    [self setNeedReopenWorkspace:YES];
    
    [super loadView];
    
    JMModalOverlay *overlay = [[JMModalOverlay alloc] init];
    [overlay setAnimates:NO];
    [overlay setDelegate:self];
    [overlay setShouldCloseWhenClickOnBackground:NO];
    [overlay setShouldOverlayTitleBar:YES];
    [overlay setBackgroundColor:[NSColor colorWithCalibratedWhite:0 alpha:.75]];
    [self setOverlay:overlay];
    PodsOverlayController *overlayController = [[PodsOverlayController alloc] init];
    [overlay setContentViewController:overlayController];
    [self setOverlayController:overlayController];
    
    [self loadAvailablePods];
}

#pragma mark
#pragma mark Datasource

- (void)loadPodsWithPath:(NSString *)path
{
    NSError *error = nil;
    NSString *podfileText = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:path] encoding:NSUTF8StringEncoding error:&error];
    
    __weak typeof(self) weakSelf = self;
    void(^loadLocalPods)() = ^{
        if (podfileText && !error) {
            [self setPodfileText:[podfileText mutableCopy]];
            
            NSRange platformNameRange = [podfileText rangeOfString:@":"];
            if (platformNameRange.location != NSNotFound) {
                platformNameRange.location += 1;
                platformNameRange.length = 3;
                NSString *platformName = [podfileText substringWithRange:platformNameRange];
                [weakSelf setPlatformName:platformName];
                
                NSUInteger firstLineBreakIndex = [podfileText rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location;
                if (firstLineBreakIndex != NSNotFound) {
                    NSString *firstLine = [podfileText substringToIndex:firstLineBreakIndex];
                    NSRange platformVersionRange = [firstLine rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet] options:NSBackwardsSearch];
                    BOOL isIOS = [weakSelf.platformName isEqualToString:@"iOS"];
                    platformVersionRange.length = isIOS ? 3 : 4;
                    platformVersionRange.location -= platformVersionRange.length - 1;
                    NSString *platformVersion = [podfileText substringWithRange:platformVersionRange];
                    [weakSelf setPlatformVersion:platformVersion];
                }
                
                NSUInteger startPodsIndex = [podfileText rangeOfString:@"pod"].location;
                if (startPodsIndex != NSNotFound) {
                    NSString *podsString = [podfileText substringFromIndex:startPodsIndex];
                    NSArray *strings = [podsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    
                    NSMutableArray *items = [NSMutableArray array];
                    [strings enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
//                        NSLog(@"POD STRING = %@", string);
                        if ([string length] > 0) {
                            PodItem *item = [[PodItem alloc] initWithString:string];
                            if (item) {
                                [items addObject:item];
                            }
                        }
                    }];
                    [weakSelf willChangeValueForKey:@"installedPods"];
                    [weakSelf.installedPods addObjectsFromArray:items];
                    [weakSelf didChangeValueForKey:@"installedPods"];
                    
                    NSString *projectPodsPath = [[weakSelf.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Pods"];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPodsPath]) {
                        [weakSelf setChanged:YES];
                    }
                }
            }
        }
    };
    
    if ([self.path isEqualToString:path]) {
        if (![self.podfileText isEqualToString:podfileText]) {
            [self willChangeValueForKey:@"installedPods"];
            [self.installedPods removeAllObjects];
            [self didChangeValueForKey:@"installedPods"];
            
            loadLocalPods();
        }
    }
    else {
        [self setPath:path];
        [self willChangeValueForKey:@"installedPods"];
        [self.installedPods removeAllObjects];
        [self didChangeValueForKey:@"installedPods"];
        
        loadLocalPods();
    }
}

- (void)loadAvailablePods
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *availablePodsTask = [[NSTask alloc] init];
        NSArray *args = @[@"list", @"--update", @"--no-color"];
        [availablePodsTask setLaunchPath:@"/usr/bin/pod"];
        [availablePodsTask setArguments:args];
        NSPipe *pipeOut = [NSPipe pipe];
        [availablePodsTask setStandardOutput:pipeOut];
        NSFileHandle *output = [pipeOut fileHandleForReading];
        NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
        environment[@"LC_ALL"]=@"en_US.UTF-8";
        [availablePodsTask setEnvironment:environment];
        [availablePodsTask launch];
        NSData *data = [output readDataToEndOfFile];
        
        NSString *list = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray *pods = [list componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSMutableArray *items = [NSMutableArray array];
        [pods enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
            PodItem *item = [[PodItem alloc] initWithName:string];
            if (item) {
                [items addObject:item];
            }
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf willChangeValueForKey:@"availablePods"];
            [weakSelf setAvailablePods:[items copy]];
            [weakSelf didChangeValueForKey:@"availablePods"];
        });
    });
}

#pragma mark
#pragma mark TableView Delegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    PodItem *item = ([tableView tag] == 666) ? [[self.installedArrayController arrangedObjects] objectAtIndex:row] : [[self.availableArrayController arrangedObjects] objectAtIndex:row];
    CGFloat nameHeight = 25;
    if (item.podDescription) {
        CGSize size = [item.podDescription boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 17, CGFLOAT_MAX) options:NSLineBreakByWordWrapping | NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[NSFont fontWithName:@"HelveticaNeue-Italic" size:13]}].size;
        CGFloat result = 33 + size.height + 8;
        return result;
    }
    return nameHeight + 10;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
    return nil;
}

#pragma mark
#pragma mark Overlay Delegate

- (void)modalOverlayDidShow:(NSNotification *)notification
{
    __weak typeof(self) weakSelf = self;
    [self installTask:^(BOOL success, NSError *error) {
        
//        NSLog(@"INSTALL COMPLETE. Succeded = %hhd, Changed = %d", success, !success);
        [weakSelf setInstallationSucceded:success];
        [weakSelf setInstallationError:error];
        
//        NSLog(@"NOW CLOSE OVERLAY");
        [weakSelf.overlayController animateProgress:NO];
        [weakSelf.overlay performSelectorOnMainThread:@selector(close) withObject:nil waitUntilDone:YES];
        [weakSelf.overlayController performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
    }];
}

- (void)modalOverlayDidClose:(NSNotification *)notification
{
//    NSLog(@"NeedReopen Flag = %hhd && InstallSucceded Flag = %d", self.needReopenWorkspace, self.installationSucceded);
    [self setChanged:!self.installationSucceded];
    if (self.needReopenWorkspace && self.installationSucceded) {
//        NSLog(@"NEED REOPEN");
        [self reopenProject:XCodeWorkspace];
    }
    else if (!self.installationSucceded) {
//        NSLog(@"NEED REOPEN, BUT INSTALL UNSUCCESFULL");
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *text = [[_installationError userInfo] valueForKey:@"reason"];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert setMessageText:@"Unable to proceed."];
        [alert setInformativeText:text];
        [alert beginSheetModalForWindow:[[self view] window] completionHandler:nil];
    }
}

- (void)checkIfWorkspaceCreated:(NSTimer*)timer
{
    NSString *workspaceFilePath = [[timer userInfo] valueForKey:@"path"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:workspaceFilePath];
    if (fileExists) {
        
        [timer invalidate];
        timer = nil;
        
        NSTask *openTask = [[NSTask alloc] init];
        NSArray *args = @[workspaceFilePath];
        [openTask setLaunchPath:@"/usr/bin/open"];
        [openTask setArguments:args];
        [openTask launch];
    }
}

#pragma mark
#pragma mark FileManager Delegate

- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error removingItemAtPath:(NSString *)path
{
    return YES;
}

#pragma mark
#pragma mark Pod Edition

- (void)didCompletePodEdition:(PodItem *)item
{
    NSString *podInstallationString = [item installStringWithVersion:item.version];
    NSUInteger startIndex = [self.podfileText rangeOfString:item.name].location;
    if (startIndex != NSNotFound) {
        NSUInteger installStringStart = [self.podfileText rangeOfString:@"pod" options:NSBackwardsSearch range:NSMakeRange(0, startIndex)].location;
        if (installStringStart != NSNotFound) {
            startIndex = installStringStart;
            NSUInteger lastIndex = [self.podfileText rangeOfString:@"\n" options:0 range:NSMakeRange(startIndex, [self.podfileText length] - startIndex)].location;
            if (lastIndex != NSNotFound) {
//                NSLog(@"Last Index = %ld %s", lastIndex, __PRETTY_FUNCTION__);
                NSUInteger length = lastIndex - startIndex;
                NSRange range = NSMakeRange(startIndex, length);
//                NSLog(@"Edited POD String %@ %s", [self.podfileText substringWithRange:range], __PRETTY_FUNCTION__);
                [self.podfileText replaceCharactersInRange:range withString:podInstallationString];
//                NSLog(@"PODFILE TEXT %@", self.podfileText);
                [[NSFileManager defaultManager] removeItemAtPath:self.path error:NULL];
                [self.podfileText writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                [self setChanged:YES];
            }
        }
    }
}

#pragma mark
#pragma mark Service

- (void)loadExtededInfo:(id)sender completion:(void (^)(PodItem*))completion
{
    NSTableView *table = [sender tag] == 666 ? self.installedTable : self.availableTable;
    NSUInteger row = [table rowForView:[sender superview]];
    PodItem *item = [(NSTableCellView*)[sender superview] objectValue];
    if (!item.inProgress) {
        [item setInProgress:YES];
        NSTableCellView *cell = (NSTableCellView*)[sender superview];
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
        [item loadDescriptionWithCompletion:^{
            [cell setNeedsLayout:YES];
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:.3];
            [table noteHeightOfRowsWithIndexesChanged:indexSet];
            [NSAnimationContext endGrouping];
            if (completion != nil) {
                completion(item);
            }
        }];
    }
    else {
        if (completion != nil) {
            completion(item);
        }
    }
}

- (void)installTask:(void(^)(BOOL, NSError*))success
{
    NSTask *installTask = [[NSTask alloc] init];
    NSArray *args = @[@"install", @"--no-color"];
    [installTask setLaunchPath:@"/usr/bin/pod"];
    [installTask setCurrentDirectoryPath:[self.path stringByDeletingLastPathComponent]];
    [installTask setArguments:args];
    NSPipe *pipeOut = [NSPipe pipe];
    [installTask setStandardOutput:pipeOut];
    NSFileHandle *output = [pipeOut fileHandleForReading];
    
    __weak typeof(self) weakSelf = self;
    __block NSError *error = nil;
    __block BOOL successFlag = YES;
    [output setReadabilityHandler:^(NSFileHandle *fileHandler) {
        NSData *data = [fileHandler availableData]; // this will read to EOF, so call only once
        NSString *text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        if ([text rangeOfString:@"[!] From now on use"].location == NSNotFound) {
            NSRange possibleErrorRange = [text rangeOfString:@"[!] "];
            if (possibleErrorRange.location != NSNotFound) {
                error = [NSError errorWithDomain:@"error::CocoaPodUI" code:666 userInfo:@{@"reason":[text substringFromIndex:NSMaxRange(possibleErrorRange)]}];
                successFlag = NO;
            }
        }
        [weakSelf.overlayController performSelectorOnMainThread:@selector(appendText:) withObject:[NSString stringWithFormat:@"\n%@", text] waitUntilDone:YES];
    }];
    
    [installTask setTerminationHandler:^(NSTask *task) {
        if (success != nil) {
            success(successFlag, error);
        }
    }];
    
    NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    environment[@"LC_ALL"]=@"en_US.UTF-8";
    [installTask setEnvironment:environment];
    [installTask launch];
    
    [installTask waitUntilExit];
}

- (void)setPlatformName:(NSString *)platformName
{
    BOOL isIOS = NO;
    if ([platformName isEqualToString:@"ios"] || [platformName isEqualToString:@"iOS"]) {
        _platformName = @"iOS";
        isIOS = YES;
    }
    else if ([platformName isEqualToString:@"osx"] || [platformName isEqualToString:@"OS X"]) {
        _platformName = @"OS X";
    }
    [self willChangeValueForKey:@"platformVersions"];
    isIOS ? [self setPlatformVersion:@"4.3"] : [self setPlatformVersion:@"10.5"];
    [self didChangeValueForKey:@"platformVersions"];
}

- (NSArray *)platformVersions
{
    if ([self.platformName isEqualToString:@"iOS"]) {
        return @[@"4.3", @"5.0", @"6.0", @"7.0"];
    }
    else {
        return @[@"10.5", @"10.6", @"10.7", @"10.8", @"10.9"];
    }
}

- (void)reopenProject:(ProjectFileType)type
{
    [self closeAction:self];
    
    __weak typeof(self) weakSelf = self;
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
    [workspaceWindowControllers enumerateObjectsUsingBlock:^(id controller, NSUInteger idx, BOOL *stop) {
        if ([[controller valueForKey:@"window"] isMainWindow]) {
            id workspaceDocument = [[controller valueForKey:@"window"] document];
            [workspaceDocument performSelectorOnMainThread:@selector(close) withObject:nil waitUntilDone:YES];
            NSString *projectFolderPath = [weakSelf.path stringByDeletingLastPathComponent];
            NSString *projectName = [projectFolderPath lastPathComponent];
            NSString *extension = type == XCodeProject ? @"xcodeproj" : @"xcworkspace";
            NSString *workspaceFilePath = [projectFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", projectName, extension]];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:workspaceFilePath];
            NSLog(@"INSTALL TO %@\nFILE EXIST = %d", workspaceFilePath,fileExists);
            if (fileExists) {
                NSTask *openTask = [[NSTask alloc] init];
                NSArray *args = @[workspaceFilePath];
                [openTask setLaunchPath:@"/usr/bin/open"];
                [openTask setArguments:args];
                [openTask launch];
            }
            else {
                NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:.5 target:weakSelf selector:@selector(checkIfWorkspaceCreated:) userInfo:@{@"path":workspaceFilePath} repeats:YES];
#pragma unused (timer)
            }
            *stop = YES;
        }
    }];
}

#pragma mark
#pragma mark IBActions

- (IBAction)loadPodInfo:(id)sender
{
    NSArrayController *aController = nil;
    NSString *key = nil;
    NSTableView *table = nil;
    if ([sender tag] == 666) {
        aController = self.availableArrayController;
        key = @"availablePods";
        table = self.availableTable;
    }
    else {
        aController = self.installedArrayController;
        key = @"installedPods";
        table = self.installedTable;
    }
    NSTableCellView *cell = (NSTableCellView*)[sender superview];
    NSInteger row =[table rowForView:cell];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:row];
    __weak typeof(self) weakSelf = self;
    [self loadExtededInfo:sender completion:^(PodItem *item) {
        if (!item) return;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name MATCHES %@", item.name];
        NSArray *filtered = [[aController arrangedObjects] filteredArrayUsingPredicate:predicate];
        if ([filtered count] == 1) {
            [weakSelf willChangeValueForKey:key];
            PodItem *sameItem = [filtered objectAtIndex:0];
            [sameItem setVersion:item.version];
            [sameItem setPodDescription:item.podDescription];
            [sameItem setIOSSupport:item.iOSSupport];
            [sameItem setOSXSupport:item.OSXSupport];
            [weakSelf didChangeValueForKey:key];
            
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:.3];
            [table noteHeightOfRowsWithIndexesChanged:indexSet];
            [NSAnimationContext endGrouping];
        }
    }];
}

- (IBAction)addPod:(id)sender
{
    __weak typeof(self) weakSelf = self;
    [self loadExtededInfo:sender completion:^(PodItem *item) {
        if (!item) return;
        
        [weakSelf willChangeValueForKey:@"installedPods"];
        [weakSelf.installedPods addObject:item];
        [weakSelf didChangeValueForKey:@"installedPods"];
        
        [weakSelf.podfileText appendString:[NSString stringWithFormat:@"%@\n", item.installString]];
        [weakSelf setChanged:YES];
    }];
}

- (IBAction)deletePod:(id)sender
{
    PodItem *item = [(NSTableCellView*)[sender superview] objectValue];
    
    BOOL hasNewLineAtTheEnd = [self.podfileText rangeOfString:[NSString stringWithFormat:@"%@\n",item.installString]].location != NSNotFound;
    [self.podfileText replaceOccurrencesOfString:hasNewLineAtTheEnd ? [NSString stringWithFormat:@"%@\n",item.installString] : item.installString withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [self.podfileText length])];
    [self setPodfileText:[[self.podfileText stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy]];
    [self.podfileText appendString:([self.podfileText rangeOfString:@"pod"].location != NSNotFound) ? @"" : @"\n"];
    
    [self willChangeValueForKey:@"installedPods"];
    [self.installedPods removeObject:item];
    [self didChangeValueForKey:@"installedPods"];
    
    [self setChanged:YES];
}

- (IBAction)saveAndInstallAction:(id)sender
{
    NSError *error = nil;
    BOOL saveSuccess = [self.podfileText writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (saveSuccess && !error) {
        if (![self.overlay isShown]) {
            [self.overlayController animateProgress:YES];
            [self.overlay showInWindow:[[self view] window]];
        }
    }
}

- (IBAction)closeAction:(id)sender
{
    [[[self view] window] close];
    [NSApp endSheet:[[self view] window]];
}

- (IBAction)editPod:(id)sender
{
    if (!self.editController) {
        [self setEditController:[[PodEditController alloc] initWithWindowNibName:@"PodEditController"]];
        [self.editController setDelegate:self];
    }
    PodItem *item = [(NSTableCellView*)[sender superview] objectValue];
    __weak typeof(self) weakSelf = self;
    void (^openEditSheetCompletion)(void) = ^{
        [weakSelf.editController setItem:item];
        [NSApp beginSheet:[weakSelf.editController window] modalForWindow:[[weakSelf view] window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
    };
    if (!item.availableVersions) {
        [item loadDescriptionWithCompletion:openEditSheetCompletion];
    }
    else {
        openEditSheetCompletion();
    }
}

- (IBAction)deleteAllPods:(id)sender
{
    NSUInteger headerLastIndex = [self.podfileText rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location;
    if (headerLastIndex != NSNotFound) {
        [self.podfileText deleteCharactersInRange:NSMakeRange(headerLastIndex + 2, self.podfileText.length - headerLastIndex - 2)];
    }
    
// Clean up pods
    NSError *error = nil;
    NSString *projectFolderPath = [self.path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
    [self.podfileText writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    [[NSFileManager defaultManager] removeItemAtPath:[self.path stringByAppendingPathExtension:@"lock"] error:&error];
    NSString *podsFolderPath = [projectFolderPath stringByAppendingPathComponent:@"Pods"];
    [[NSFileManager defaultManager] removeItemAtPath:podsFolderPath error:&error];
    NSString *projectName = [projectFolderPath lastPathComponent];
    NSString *workspaceFilePath = [projectFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xcworkspace", projectName]];
    [[NSFileManager defaultManager] removeItemAtPath:workspaceFilePath error:&error];
    
// Clean up project
    NSString *projectSettingsFilePath = [projectFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xcodeproj/project.pbxproj", projectName]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:projectSettingsFilePath];
    NSMutableDictionary *objects = [settings objectForKey:@"objects"];
    
    NSPredicate *podsResourcesPredicate = [NSPredicate predicateWithFormat:@"SELF.name MATCHES %@", @"Copy Pods Resources"];
    NSArray *filteredResources = [[objects allValues] filteredArrayUsingPredicate:podsResourcesPredicate];
    if ([filteredResources count] == 1) {
        NSString *key = [[objects allKeysForObject:[filteredResources objectAtIndex:0]] objectAtIndex:0];
        [objects removeObjectForKey:key];
    }
    
    NSPredicate *manifestPredicate = [NSPredicate predicateWithFormat:@"SELF.name MATCHES %@", @"Check Pods Manifest.lock"];
    NSArray *filteredManifest = [[objects allValues] filteredArrayUsingPredicate:manifestPredicate];
    if ([filteredManifest count] == 1) {
        NSString *key = [[objects allKeysForObject:[filteredManifest objectAtIndex:0]] objectAtIndex:0];
        [objects removeObjectForKey:key];
    }
    
    NSPredicate *podsxcconfigPredicate = [NSPredicate predicateWithFormat:@"SELF.name MATCHES %@", @"Pods.xcconfig"];
    NSArray *filteredPodsxcconfig = [[objects allValues] filteredArrayUsingPredicate:podsxcconfigPredicate];
    if ([filteredPodsxcconfig count] == 1) {
        NSString *key = [[objects allKeysForObject:[filteredPodsxcconfig objectAtIndex:0]] objectAtIndex:0];
        [objects removeObjectForKey:key];
    }
    
    NSPredicate *libPodPredicate = [NSPredicate predicateWithFormat:@"SELF.path MATCHES %@", @"libPods.a"];
    NSArray *filteredLibPod = [[objects allValues] filteredArrayUsingPredicate:libPodPredicate];
    if ([filteredLibPod count] == 1) {
        NSString *key = [[objects allKeysForObject:[filteredLibPod objectAtIndex:0]] objectAtIndex:0];
        [objects removeObjectForKey:key];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:projectSettingsFilePath error:&error];
    [settings writeToFile:projectSettingsFilePath atomically:YES];
    
    [self willChangeValueForKey:@"installedPods"];
    [self.installedPods removeAllObjects];
    [self didChangeValueForKey:@"installedPods"];
    
    if (self.needReopenWorkspace) {
        [self reopenProject:XCodeProject];
    }
    
//    [[NSNotificationCenter defaultCenter] postNotificationName:kUserDidDeleteAllPods object:nil];
}
@end
