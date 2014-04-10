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
#import "PodCell.h"
#import "JMModalOverlay.h"

#import "NSObject+IDEKit.h"
#import "NSString+Extra.h"

#import <YAMLSerialization.h>

#import <pthread.h>

static NSString *const kReposDidRead = @"CococaPodUI:ReposDidRead";

#define kAccessoryViewFieldTag 666

typedef NS_ENUM(NSUInteger, ProjectFileType) {
    XCodeProject,
    XCodeWorkspace
};

typedef NS_ENUM(NSUInteger, PodTaskName) {
    kReadPodfileTaskName,
    kInstallTaskName
};

@interface PodsManagementViewController () <NSTableViewDelegate, NSTableViewDataSource, JMModalOverlayDelegate, NSFileManagerDelegate, PodEdtitionDelegate>
{
@private
    NSArray *_sortedAvailableKeys;
    id _reposReadStateObserver;
}
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
@property (assign, nonatomic) BOOL availablePodsReaded;
@property (assign, nonatomic) BOOL enableConsoleOutput;
@property (copy) NSError *installationError;

@property (strong, nonatomic) NSMutableString *podfileText;
@property (weak) IBOutlet NSTableView *installedTable;
@property (weak) IBOutlet NSTableView *availableTable;

- (IBAction)saveAndInstallAction:(id)sender;
- (IBAction)closeAction:(id)sender;
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
    [self setEnableConsoleOutput:YES];
    
    [super loadView];
    
    [self setupNotifications];
    
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
    
    [self performSelectorInBackground:@selector(loadAvailablePods) withObject:nil];
}

#pragma mark
#pragma mark Notification handle

- (void)setupNotifications
{
    __weak typeof(self) weakSelf = self;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    _reposReadStateObserver = [center addObserverForName:kReposDidRead object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf setAvailablePodsReaded:YES];
        [weakSelf performSelectorOnMainThread:@selector(completeInstalledPods) withObject:nil waitUntilDone:YES];
    }];
    
    [center addObserver:self selector:@selector(addPod:) name:kAddPodNotificationName object:nil];
    [center addObserver:self selector:@selector(editPod:) name:kEditPodNotificationName object:nil];
    [center addObserver:self selector:@selector(deletePod:) name:kDeletePodNotificationName object:nil];
}

#pragma mark
#pragma mark Datasource

- (void)loadPodsWithPath:(NSString *)path
{
    [self setPath:path];
    
    NSTask *podfileTask = [[NSTask alloc] init];
    NSArray *args = @[@"ipc", @"podfile", path, @"--no-color"];
    NSString *launchPath = [[NSUserDefaults standardUserDefaults] valueForKey:kPodGemPathKey];
    [podfileTask setLaunchPath:launchPath];
    [podfileTask setArguments:args];
    NSPipe *pipeOut = [NSPipe pipe];
    [podfileTask setStandardOutput:pipeOut];
    NSFileHandle *output = [pipeOut fileHandleForReading];
    NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    environment[@"LC_ALL"]=@"en_US.UTF-8";
    [podfileTask setEnvironment:environment];
    
    @try {
        [podfileTask launch];
    }
    @catch (NSException *exception) {
        [self podGemTaskExeption:exception wrongPath:launchPath task:kReadPodfileTaskName];
        return;
    }
    
    NSData *yamlData = [output readDataToEndOfFile];
    if ([yamlData length] > 0) {
        NSError *error = nil;
        NSDictionary *obj = [YAMLSerialization objectWithYAMLData:yamlData options:kYAMLReadOptionStringScalars error:&error];
        if (obj && !error) {
            [self setPodfileText:[[NSMutableString alloc] initWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:&error]];
            NSArray *definitions = [obj valueForKey:@"target_definitions"];
            if ([definitions count] == 1) {
                NSDictionary *info = [definitions objectAtIndex:0];
                
                NSDictionary *platformInfo = [info valueForKey:@"platform"];
                [self setPlatformName:[[platformInfo allKeys] firstObject]];
                [self setPlatformVersion:[[platformInfo allValues] firstObject]];
                
                NSArray *dependencies = [info valueForKey:@"dependencies"];
                NSMutableArray *pods = [NSMutableArray array];
                __weak typeof(self) weakSelf = self;
                [dependencies enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
                    PodItem *item = [[PodItem alloc] init];
                    if ([object isKindOfClass:[NSString class]]) {
                        [item setName:object];
                        [item setVersionModifier:@"Version logic"];
                    }
                    else if ([object isKindOfClass:[NSDictionary class]]) {
                        [item setName:[[object allKeys] firstObject]];
                        NSString *versionString = [[[object allValues] firstObject] firstObject];
                        NSArray *versionComponents = [versionString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        if ([versionComponents count] == 1) {
                            if ([[versionComponents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF = %@", @"~>"]] count] == 0) {
                                [item setVersion:[versionComponents firstObject]];
                            }
                            [item setVersionModifier:@"Version logic"];
                        }
                        else if ([versionComponents count] > 1) {
                            [item setVersionModifier:[versionComponents objectAtIndex:0]];
                            [item setVersion:[versionComponents objectAtIndex:1]];
                        }
                    }
                    if ([item.name length] > 0) {
                        [pods addObject:item];
                    }
                }];
                [weakSelf setInstalledPods:[[NSArray arrayWithArray:pods] mutableCopy]];
                
                if (weakSelf.availablePodsReaded) {
                    [weakSelf completeInstalledPods];
                }
                
                NSString *podsDirPath = [[self.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Pods"];
                BOOL isDir;
                BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:podsDirPath isDirectory:&isDir];
                [self setChanged:!(exists && isDir)];
                
                [self.installedTable reloadData];
            }
        }
    }
}

- (void)specifyPodGemLocation:(id)sender
{
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowsMultipleSelection:NO];
    [open beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            NSString *path = [[open URL] path];
            NSTextField *field = [[sender superview] viewWithTag:kAccessoryViewFieldTag];
            [field setStringValue:path];
        }
    }];
}

- (void)completeInstalledPods
{
    NSString *podfileLockPath = [[self.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Podfile.lock"];
    NSError *error = nil;
    
    __weak typeof(self) weakSelf = self;
    if ([[NSFileManager defaultManager] fileExistsAtPath:podfileLockPath]) {
        NSString *podfileLockString = [NSString stringWithContentsOfFile:podfileLockPath encoding:NSUTF8StringEncoding error:&error];
        if (podfileLockString && !error) {
            NSString *podsSubstring = [podfileLockString stringBetweenString:@"PODS:\n  - " andString:@"DEPENDENCIES:"];
            podsSubstring = [podsSubstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSArray *components = [podsSubstring componentsSeparatedByString:@"\n  - "];
            [components enumerateObjectsUsingBlock:^(NSString *item, NSUInteger idx, BOOL *stop) {
                NSArray *parts = [item componentsSeparatedByString:@" "];
                NSString *name = [parts firstObject];
                NSCharacterSet *minus = [NSCharacterSet characterSetWithCharactersInString:@"():\n"];
                NSString *version = [[parts objectAtIndex:1] stringByTrimmingCharactersInSet:minus];
                NSArray *filteredInstalled = [weakSelf.installedPods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", name]];
                if ([filteredInstalled count] == 1) {
                    PodItem *installedItem = [filteredInstalled firstObject];
                    [installedItem setVersion:version];
                    PodItem *availableItem = [[weakSelf.availablePods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", name]] firstObject];
                    [installedItem setSummary:availableItem.summary];
                    [installedItem setVersions:availableItem.versions];
                }
            }];
        }
    }
    else {
        [self.installedPods enumerateObjectsUsingBlock:^(PodItem *item, NSUInteger idx, BOOL *stop) {
            PodItem *availableItem = [[weakSelf.availablePods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", item.name]] firstObject];
            if ([item.version length] == 0) {
                [item setVersion:availableItem.version];
            }
            [item setSummary:availableItem.summary];
            [item setVersions:availableItem.versions];
            if (!item.versionModifier) {
                [item setVersionModifier:@"Version logic"];
            }
        }];
    }
}

- (void)loadAvailablePods
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *localRepoPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cocoapods/repos/master"];
    NSError *error = nil;
    NSArray *localRepoContent = [fileManager contentsOfDirectoryAtPath:localRepoPath error:&error];
    NSMutableArray *repos = [NSMutableArray array];
    [localRepoContent enumerateObjectsUsingBlock:^(NSString *podName, NSUInteger idx, BOOL *stop) {
        NSError *internalError = nil;
        if (![podName hasPrefix:@"."]) {
            NSString *podRepoPath = [localRepoPath stringByAppendingPathComponent:podName];
            NSArray *podVersions = [[fileManager contentsOfDirectoryAtPath:podRepoPath error:&internalError] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            NSString *maxVersion = [podVersions lastObject];
            NSString *podspecPath = [[podRepoPath stringByAppendingPathComponent:maxVersion] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.podspec", podName]];
            BOOL isDir;
            BOOL exists = [fileManager fileExistsAtPath:podspecPath isDirectory:&isDir];
            if (exists && !isDir) {
                NSData *podspecData = [NSData dataWithContentsOfFile:podspecPath];
                PodItem *item = [[PodItem alloc] init];
                [item setRepoPath:podspecPath];
                [item setPodspecData:podspecData];
                [item setVersions:podVersions];
                [item setName:podName];
                [item setVersionModifier:@"Version logic"];
                [repos addObject:item];
            }
        }
    }];
    [self performSelectorOnMainThread:@selector(updateAvailableContent:) withObject:repos waitUntilDone:YES];
}

- (void)updateAvailableContent:(NSArray*)content
{
    [self willChangeValueForKey:@"availablePods"];
    [self setAvailablePods:[NSArray arrayWithArray:content]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kReposDidRead object:nil];
    [self didChangeValueForKey:@"availablePods"];
}

#pragma mark
#pragma mark Pod gem task exeptions handling

- (void)podGemTaskExeption:(NSException*)exception wrongPath:(NSString*)launchPath task:(PodTaskName)task
{
    NSString *reason = [exception reason];
    if ([reason isEqualToString:@"launch path not accessible"] || [reason isEqualToString:@"must provide a launch path"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Cocoapods gem not found"];
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 4, 200, 20)];
        [[field cell] setPlaceholderString:@"\"Pod\" gem path"];
        [field setTag:kAccessoryViewFieldTag];
        [[field cell] setLineBreakMode:NSLineBreakByTruncatingHead];
        
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(208, 0, 135, 24)];
        [btn setTitle:@"Specify gem location"];
        [btn setButtonType:NSMomentaryPushButton];
        [btn setBezelStyle:NSRoundedBezelStyle];
        [btn setTarget:self];
        [btn setAction:@selector(specifyPodGemLocation:)];
        
        NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 345, 30)];
        [accessoryView addSubview:field];
        [accessoryView addSubview:btn];
        
        [alert setAccessoryView:accessoryView];
        [alert setInformativeText:[NSString stringWithFormat:@"CocoaPodUI can't find \"pod\" gem at default %@ folder. You can specify it's location manually", [launchPath stringByDeletingLastPathComponent]]];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert beginSheetModalForWindow:[[self view] window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:(__bridge void *)([NSNumber numberWithUnsignedInteger:task])];
    }
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == 1000) {
        NSTextField *field = [[alert accessoryView] viewWithTag:kAccessoryViewFieldTag];
        NSString *path = [field stringValue];
        if ([path length] > 0) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSUserDefaults standardUserDefaults] setValue:[path copy] forKey:kPodGemPathKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                PodTaskName task = [(__bridge NSNumber*)(contextInfo) unsignedIntegerValue];
                if (task == kReadPodfileTaskName) {
                    [self loadPodsWithPath:self.path];
                }
            }
        }
    }
}

#pragma mark
#pragma mark TableView Delegate && DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.installedPods count];
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    static NSString *installed = @"installed";
    PodCell *view = [tableView makeViewWithIdentifier:installed owner:nil];
    PodItem *item = [self.installedPods objectAtIndex:row];
    [view setObjectValue:item];
    
    return view;
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
    [self setChanged:YES];
}

#pragma mark
#pragma mark Service

- (void)installTask:(void(^)(BOOL, NSError*))success
{
    NSTask *installTask = [[NSTask alloc] init];
    NSArray *args = @[@"install", @"--no-color"];
    NSString *launchPath = [[NSUserDefaults standardUserDefaults] valueForKey:kPodGemPathKey];
    [installTask setLaunchPath:launchPath];
    [installTask setCurrentDirectoryPath:[self.path stringByDeletingLastPathComponent]];
    [installTask setArguments:args];
    NSPipe *pipeOut = [NSPipe pipe];
    [installTask setStandardOutput:pipeOut];
    NSFileHandle *output = [pipeOut fileHandleForReading];
    
    __weak typeof(self) weakSelf = self;
    __block NSError *error = nil;
    __block BOOL successFlag = YES;
    id logView = self.enableConsoleOutput ? [self logView:nil] : nil;
//    NSLog(@"%@", logView);
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
        NSString *logString = [NSString stringWithFormat:@"\n%@", text];
        [weakSelf.overlayController performSelectorOnMainThread:@selector(appendText:) withObject:logString waitUntilDone:YES];
        if (logView) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSString *trimmed = [logString stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                [df setDateFormat:@"yyyy-MM-dd hh:mm:ss.SSS"];
                NSString *time = [df stringFromDate:[NSDate date]];
                int pid = getpid();
                int tid = pthread_mach_thread_np(pthread_self());
                NSAttributedString *aString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ CocoaPodUI[%d:%d] %@", time, pid, tid, trimmed] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13], NSForegroundColorAttributeName:RGB(0, 196, 29)}];
                [logView setLogMode:1];
                [logView insertText:aString];
                [logView insertNewline:self];
                [logView setLogMode:0];
            });
        }
    }];
    
    [installTask setTerminationHandler:^(NSTask *task) {
        if (success != nil) {
            success(successFlag, error);
        }
    }];
    
    NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    environment[@"LC_ALL"]=@"en_US.UTF-8";
    [installTask setEnvironment:environment];
    @try {
        [installTask launch];
    }
    @catch (NSException *exception) {
        [self podGemTaskExeption:exception wrongPath:launchPath task:kInstallTaskName];
        return;
    }
    
    [installTask waitUntilExit];
}

- (NSString*)podfileString
{
    NSMutableString *podfileText = [[self.podfileText stringByreplacingOccurrencesOfCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"`\""] withString:@"'"] mutableCopy];
    NSString *firstLine = [[podfileText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] firstObject];
    NSRange range = [podfileText rangeOfString:firstLine];
    if (range.location != NSNotFound) {
        NSString *header = [NSString stringWithFormat:@"platform :%@, '%@'\n", [[self.platformName lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""], self.platformVersion];
        [podfileText replaceCharactersInRange:range withString:header];
    }
    
    NSUInteger startPodsSection = [self.podfileText rangeOfString:@"pod "].location;
    if (startPodsSection != NSNotFound) {
        __block NSUInteger length = 0;
        [podfileText enumerateSubstringsInRange:NSMakeRange(startPodsSection, [podfileText length] - startPodsSection) options:NSStringEnumerationByLines usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            if ([substring hasPrefix:@"pod"]) {
                length += substringRange.length;
            }
        }];
        NSMutableString *inTable = [NSMutableString string];
        [self.installedPods enumerateObjectsUsingBlock:^(PodItem *item, NSUInteger idx, BOOL *stop) {
            if ([item.versionModifier length] == 0 || [item.versionModifier isEqualToString:@"Version logic"]) {
                [inTable appendFormat:@"%@pod '%@', '%@'", idx == 0 ? @"" : @"\n", item.name, item.version];
            }
            else {
                [inTable appendFormat:@"%@pod '%@', '%@ %@'", idx == 0 ? @"" : @"\n", item.name, item.versionModifier, item.version];
            }
        }];
        [podfileText replaceCharactersInRange:NSMakeRange(startPodsSection, ++length) withString:inTable];
    }
    return [NSString stringWithString:podfileText];
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
            //            NSLog(@"INSTALL TO %@\nFILE EXIST = %d", workspaceFilePath,fileExists);
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
#pragma mark IDE

- (id)logView:(NSView*)parent
{
    if (!parent) {
        parent = [[NSApp mainWindow] contentView];
    }
    __block id logView = nil;
    __weak typeof(self) weakSelf = self;
    [[parent subviews] enumerateObjectsUsingBlock:^(NSView *obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:NSClassFromString(@"IDEConsoleTextView")]) {
            logView = obj;
            *stop = YES;
        }
        else {
            NSView *child = [weakSelf logView:obj];
            if ([child isKindOfClass:NSClassFromString(@"IDEConsoleTextView")]) {
                logView = child;
                *stop = YES;
            }
        }
    }];
    return logView;
}

#pragma mark
#pragma mark IBActions

- (void)addPod:(NSNotification*)note
{
    PodItem *item = [[note object] copy];
    if (item) {
        [self.installedPods addObject:item];
        [self setChanged:YES];
        [self.installedTable insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:[self.installedPods indexOfObject:item]] withAnimation:NSTableViewAnimationSlideRight];
    }
}

- (void)editPod:(NSNotification*)note
{
    if (!self.editController) {
        [self setEditController:[[PodEditController alloc] initWithWindowNibName:@"PodEditController"]];
        [self.editController setDelegate:self];
    }
    PodItem *item = [note object];
    if (item) {
        [self.editController setItem:item];
        [self setChanged:YES];
        [NSApp beginSheet:[self.editController window] modalForWindow:[[self view] window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
    }
}

- (void)deletePod:(NSNotification*)note
{
    PodItem *item = [note object];
    if (item) {
        if ([self.installedPods containsObject:item]) {
            [self setChanged:YES];
            NSUInteger index = [self.installedPods indexOfObject:item];
            [self.installedPods removeObject:item];
            [self.installedTable removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationSlideRight];
        }
    }
}

- (IBAction)saveAndInstallAction:(id)sender
{
    NSString *podfileString = [self podfileString];
//    NSLog(@"%@", podfileString);
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
    BOOL saveSuccess = [podfileString writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (saveSuccess && !error) {
        [self setPodfileText:[podfileString mutableCopy]];
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
}

#pragma mark
#pragma mark Memory

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_reposReadStateObserver];
    _reposReadStateObserver = nil;
}
@end
