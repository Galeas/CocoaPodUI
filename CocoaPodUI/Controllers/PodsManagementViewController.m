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
#import "MainWindowController.h"
#import "PodEditController.h"
#import "PodsOverlayController.h"
#import "PodItem.h"
#import "PodCell.h"
#import "JMModalOverlay.h"

#import "NSObject+IDEKit.h"
#import "NSString+Extra.h"
#import "JMModalOverlay+Task.h"

#import <YAMLSerialization.h>
#import "PodfileParser.h"

#import <pthread.h>
#import "PodTask.h"

static NSString *const kReposDidRead = @"CococaPodUI:ReposDidRead";

#define kPodDataType @"CocoaPodUI:PodDataType"
#define kAccessoryViewFieldTag 666
#define kSaveButtonTag         999

typedef NS_ENUM(NSUInteger, ProjectFileType) {
    XCodeProject,
    XCodeWorkspace
};

@interface PodsManagementViewController () <NSTableViewDelegate, NSTableViewDataSource, JMModalOverlayDelegate, NSFileManagerDelegate, PodEdtitionDelegate, NSTextFieldDelegate>
{
@private
    NSArray *_sortedAvailableKeys;
    id _reposReadStateObserver;
    PodfileParser *_parser;
}
@property (copy) NSString *path;
@property (strong, nonatomic) JMModalOverlay *overlay;
@property (strong, nonatomic) PodsOverlayController *overlayController;
@property (strong, nonatomic) PodEditController *editController;

@property (strong, nonatomic) NSString *platformName;
@property (strong, nonatomic) NSString *platformVersion;
@property (readonly) NSArray *platformVersions;
@property (copy) NSError *installationError;;
@property (strong, nonatomic) NSMutableDictionary *outdatedSheet;

@property (assign, nonatomic) BOOL changed;
@property (assign, nonatomic) BOOL needReopenWorkspace;
@property (assign, nonatomic) BOOL installationSucceded;
@property (assign, nonatomic) BOOL availablePodsReaded;
@property (assign, nonatomic) BOOL enableConsoleOutput;
@property (assign, nonatomic) BOOL needCheckOutdated;
@property (assign, nonatomic) BOOL needOutdatedCounter;
@property (assign, nonatomic) BOOL hasOutdated;

@property (weak) IBOutlet NSTableView *installedTable;
@property (weak) IBOutlet NSTableView *availableTable;
@property (weak) IBOutlet NSProgressIndicator *repoReadProgressBar;
@property (weak) IBOutlet NSButton *updateButton;

- (IBAction)saveAndInstallAction:(id)sender;

- (IBAction)closeAction:(id)sender;
- (IBAction)deleteAllPods:(id)sender;
- (IBAction)deleteTarget:(id)sender;
- (IBAction)addTarget:(id)sender;

- (IBAction)switchOutdatedCheck:(id)sender;
- (IBAction)switchOutdatedBadge:(id)sender;
- (IBAction)updatePods:(id)sender;
@end

@implementation PodsManagementViewController

- (id)init
{
    self = [super initWithNibName:@"PodsManagementViewController" bundle:[NSBundle bundleForClass:[self class]]];
    if (self) {
        [self setInstalledPods:[NSMutableArray array]];
        [[NSFileManager defaultManager] setDelegate:self];
        
        [self setNeedCheckOutdated:[[NSUserDefaults standardUserDefaults] boolForKey:kNeedCheckOutdatedPods]];
        [self setNeedOutdatedCounter:[[NSUserDefaults standardUserDefaults] boolForKey:kNeedShowOutdatedPodsCount]];
        
        self->_outdatedSheet = [NSMutableDictionary dictionary];
        [NSApp addObserver:self forKeyPath:@"mainWindow" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSString *title = [[NSApp mainWindow] title];
    if (title && self.needOutdatedCounter) {
        NSArray *keys = [[self.outdatedSheet allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%@ BEGINSWITH SELF", title]];
        if ([keys count] == 1) {
            NSUInteger outdatedCount = [[self.outdatedSheet valueForKey:[keys firstObject]] unsignedIntegerValue];
            [[NSApp dockTile] setBadgeLabel:outdatedCount > 0 ? [NSString stringWithFormat:@"%ld", outdatedCount] : nil];
        }
        else {
            [[NSApp dockTile] setBadgeLabel:nil];
        }
    }
}

- (void)loadView
{
    [self setNeedReopenWorkspace:YES];
    [self setEnableConsoleOutput:YES];
    [self setHasOutdated:NO];
    
    [super loadView];
    
    [self.updateButton setEnabled:NO];
    [self.installedTable registerForDraggedTypes:@[kPodDataType]];
    [self.availableTable registerForDraggedTypes:@[kPodDataType]];
    
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
    
    [self.repoReadProgressBar setHidden:NO];
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
    NSPipe *pipeOut = [NSPipe pipe];
    [podfileTask setStandardOutput:pipeOut];
    NSFileHandle *output = [pipeOut fileHandleForReading];
    
    NSString *launchPath = nil;
    NSArray *args = nil;

    @try {
        launchPath = [[NSUserDefaults standardUserDefaults] valueForKey:kPodGemPathKey];
        args = @[@"ipc", @"podfile", path];
//        DLog(@"CocoaPodUI::%s ~ LaunchPath:%@", __PRETTY_FUNCTION__, launchPath);

        [podfileTask setLaunchPath:launchPath];
        [podfileTask setArguments:args];
        NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
        environment[@"LC_ALL"]=@"en_US.UTF-8";
        [podfileTask setEnvironment:environment];

//        DLog(@"CocoaPodUI::%s ~ Try to Launch", __PRETTY_FUNCTION__);
        [podfileTask launch];
    }
    @catch (NSException *exception) {
//        DLog(@"CocoaPodUI::%s ~ Exception Reason:%@", __PRETTY_FUNCTION__, exception.reason);
        [self podGemTaskExeption:exception wrongPath:launchPath task:kReadPodfileTaskName];
        return;
    }
    
    NSData *yamlData = [output readDataToEndOfFile];
    if ([yamlData length] > 0) {
        NSError *error = nil;
        NSDictionary *obj = [YAMLSerialization objectWithYAMLData:yamlData options:kYAMLReadOptionStringScalars error:&error];
        if (obj && !error) {
            _parser = [PodfileParser parserWithContentsOfFile:self.path];
            NSArray *children = [[[obj valueForKey:@"target_definitions"] firstObject] valueForKey:@"children"];
            NSMutableArray *pods = [NSMutableArray array];
            void(^dependenciesBlock)(id, NSUInteger, BOOL*) = ^(id object, NSUInteger idx, BOOL *stop){
                PodItem *item = [[PodItem alloc] init];
                if ([object isKindOfClass:[NSString class]]) {
                    [item setName:object];
                }
                else if ([object isKindOfClass:[NSDictionary class]]) {
                    [item setName:[[object allKeys] firstObject]];
                    NSArray *props = [[object allValues] firstObject];
                    [props enumerateObjectsUsingBlock:^(id property, NSUInteger idx, BOOL *stop) {
                        if ([property isKindOfClass:[NSString class]]) {
                            NSArray *versionComponents = [property componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                            if ([versionComponents count] == 1) {
                                [item setVersion:[versionComponents firstObject]];
                                [item setVersionModifier:kVersionModeEquals];
                            }
                            else if ([versionComponents count] > 1) {
                                [item setVersionModifier:[versionComponents firstObject]];
                                [item setVersion:[versionComponents objectAtIndex:1]];
                            }
                        }
                        else if ([property isKindOfClass:[NSDictionary class]]) {
                            [(NSDictionary*)property enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
                                if ([key isEqualToString:@":git"]) {
                                    [item setGitURL:[NSURL URLWithString:value]];
                                }
                                else if ([key isEqualToString:@":commit"]) {
                                    [item setCommit:value];
                                }
                                else if ([key isEqualToString:@":podspec"]) {
                                    [item setPodspecURL:[NSURL URLWithString:value]];
                                }
                                else if ([key isEqualToString:@":path"]) {
                                    [item setPath:value];
                                }
                            }];
                        }
                    }];
                }
                if ([item.name length] > 0) {
                    [pods addObject:item];
                }
            };
            
            NSDictionary *platformInfo = nil;
            if (children) {
                platformInfo = [[[obj valueForKey:@"target_definitions"] firstObject] valueForKey:@"platform"];
                [children enumerateObjectsUsingBlock:^(NSDictionary *target, NSUInteger idx, BOOL *stop) {
                    NSArray *dependencies = [target valueForKey:@"dependencies"];
                    NSString *name = [target valueForKey:@"name"];
                    [pods addObject:name];
                    [dependencies enumerateObjectsUsingBlock:dependenciesBlock];
                }];
                [self setInstalledPods:pods];
            }
            else {
                NSArray *definitions = [obj valueForKey:@"target_definitions"];
                if ([definitions count] == 1) {
                    NSDictionary *info = [definitions firstObject];
                    platformInfo = [info valueForKey:@"platform"];
                    
                    NSArray *dependencies = [info valueForKey:@"dependencies"];
                    [dependencies enumerateObjectsUsingBlock:dependenciesBlock];
                }
                [self setInstalledPods:pods];
            }
            [self setPlatformName:[[platformInfo allKeys] firstObject]];
            [self setPlatformVersion:[[platformInfo allValues] firstObject]];
            
            if (self.availablePodsReaded) {
                [self completeInstalledPods];
            }
            
            NSString *podsDirPath = [[self.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Pods"];
            BOOL isDir;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:podsDirPath isDirectory:&isDir];
            [self setChanged:!(exists && isDir)];
            
            [self.installedTable reloadData];
            if (self.needCheckOutdated) {
                [self switchOutdatedCheck:self];
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
            NSString *podsSubstring = [[podfileLockString stringBetweenString:@"PODS:\n  - " andString:@"DEPENDENCIES:"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [podsSubstring enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
                NSString *fLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -\t"]];
                NSArray *parts = [fLine componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *name = [parts firstObject];
                NSString *versionsSubs = [[parts lastObject] stringBetweenString:@"(" andString:@")"];
                NSArray *versionParts = [versionsSubs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSArray *filtered = [weakSelf.installedPods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", name]];
                [filtered enumerateObjectsUsingBlock:^(PodItem *item, NSUInteger idx, BOOL *stop) {
                    PodItem *availableItem = [[weakSelf.availablePods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", name]] firstObject];
                    [item setSummary:availableItem.summary];
                    [item setVersions:availableItem.versions];
                    if ([item.version length] == 0) {
                        [item setVersion:[versionParts count] == 1 ? [versionParts firstObject] : [versionParts lastObject]];
                    }
                    if ([item.versionModifier length] == 0) {
                        [item setVersionModifier:[versionParts count] == 1 ? kVersionModeEmpty : [versionParts firstObject]];
                    }
                }];
            }];
        }
    }
    else {
        [self.installedPods enumerateObjectsUsingBlock:^(id item, NSUInteger idx, BOOL *stop) {
            if ([item isKindOfClass:[PodItem class]]) {
                PodItem *availableItem = [[weakSelf.availablePods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name = %@", [(PodItem*)item name]]] firstObject];
                if ([[(PodItem*)item version] length] == 0) {
                    [item setVersion:availableItem.version];
                }
                [item setSummary:availableItem.summary];
                [item setVersions:availableItem.versions];
                if (![(PodItem*)item versionModifier]) {
                    [item setVersionModifier:kVersionModeEquals];
                }
            }
        }];
    }
}

- (void)loadAvailablePods
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *localRepoPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cocoapods/repos/master/Specs"];
    NSError *error = nil;
    NSArray *localRepoContent = [fileManager contentsOfDirectoryAtPath:localRepoPath error:&error];
    NSMutableArray *repos = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [self.repoReadProgressBar setMaxValue:[localRepoContent count]];
    [localRepoContent enumerateObjectsUsingBlock:^(NSString *podName, NSUInteger idx, BOOL *stop) {
        if (![podName hasPrefix:@"."]) {
            NSError *internalError = nil;
            NSString *podRepoPath = [localRepoPath stringByAppendingPathComponent:podName];
            NSArray *podVersions = [[fileManager contentsOfDirectoryAtPath:podRepoPath error:&internalError] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            NSString *maxVersion = [podVersions lastObject];
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[podRepoPath stringByAppendingPathComponent:maxVersion] error:&internalError];
            if (!internalError) {
                NSString *fileName = [[files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", podName]] firstObject];
                if ([fileName length] > 0) {
                    NSString *fullPath = [[podRepoPath stringByAppendingPathComponent:maxVersion] stringByAppendingPathComponent:fileName];
                    PodItem *item = [[PodItem alloc] initWithPath:fullPath];
                    [item setVersions:podVersions];
                    [repos addObject:item];
                }
            }
        }
        [weakSelf.repoReadProgressBar setDoubleValue:idx];
    }];
    [self performSelectorOnMainThread:@selector(updateAvailableContent:) withObject:repos waitUntilDone:YES];
}

- (void)updateAvailableContent:(NSArray*)content
{
    [self.repoReadProgressBar setHidden:YES];
    [self willChangeValueForKey:@"availablePods"];
    [self setAvailablePods:[NSArray arrayWithArray:content]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kReposDidRead object:nil];
    [self didChangeValueForKey:@"availablePods"];
}

#pragma mark
#pragma mark Pod gem task exeptions handling

- (void)podGemTaskExeption:(NSException*)exception wrongPath:(NSString*)launchPath task:(PodTask)task
{
    DLog(@"CocoaPodUI::%s ~ Exception Handling", __PRETTY_FUNCTION__);
    
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
        
        DLog(@"CocoaPodUI::%s ~ Alert created", __PRETTY_FUNCTION__);
        
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
                PodTask task = [(__bridge NSNumber*)(contextInfo) unsignedIntegerValue];
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

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    return [self.installedPods count] == 0 ? NO : [[self.installedPods objectAtIndex:row] isKindOfClass:[NSString class]];
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    static NSString *installed = @"installed";
    static NSString *target = @"target";
    id item = [self.installedPods objectAtIndex:row];
    if ([item isKindOfClass:[NSString class]]) {
        NSTableCellView *targetCell = [tableView makeViewWithIdentifier:target owner:self];
        [targetCell setObjectValue:item];
        return targetCell;
    }
    else if ([item isKindOfClass:[PodItem class]]) {
        PodCell *view = [tableView makeViewWithIdentifier:installed owner:self];
        [view setObjectValue:item];
        return view;
    }
    return nil;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    id item = [self.installedPods objectAtIndex:row];
    return [item isKindOfClass:[NSString class]] ? 25.0f : 72.0f;
}

#pragma mark TableView Drag&Drop

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    id item = [self.installedPods objectAtIndex:[rowIndexes firstIndex]];
    if ([item isKindOfClass:[PodItem class]]) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
        [pboard declareTypes:@[kPodDataType] owner:self];
        [pboard setData:data forType:kPodDataType];
        return YES;
    }
    return NO;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    return dropOperation == NSTableViewDropAbove ? NSDragOperationMove : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    if (dropOperation == NSTableViewDropAbove) {
        NSPasteboard *pboard = [info draggingPasteboard];
        NSData *data = [pboard dataForType:kPodDataType];
        PodItem *item = nil;
        if ([info draggingSource] != self.installedTable) {
            item = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        else {
            NSIndexSet *indexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            item = [self.installedPods objectAtIndex:[indexes firstIndex]];
        }
        [self.installedPods removeObject:item];
        NSUInteger index = row <= [self.installedPods count] ? row : [self.installedPods count];
        [self.installedPods insertObject:item atIndex:index];
        [self.installedTable reloadData];
        [self setChanged:YES];
        return YES;
    }
    return NO;
}

#pragma mark
#pragma mark Overlay Delegate

- (void)modalOverlayDidShow:(NSNotification *)notification
{
//    DLog(@"%@", [notification object]);
    PodTask task = [(JMModalOverlay*)[notification object] task];
    DLog(@"COCOAPODUI::TASK::%@", task == kUpdateTaskName ? @"Update" : @"Install");
    __weak typeof(self) weakSelf = self;
    [self installTask:task completion:^(BOOL success, NSError *error) {
        
        DLog(@"INSTALL COMPLETE. Succeded = %hhd, Changed = %d", success, !success);
        [weakSelf setInstallationSucceded:success];
        [weakSelf setInstallationError:error];
        
        DLog(@"NOW CLOSE OVERLAY");
        dispatch_async(dispatch_get_main_queue(), ^{
            DLog(@"COCOAPODUI::OVERLAY_CONTROLLER:%@ ~~ OVERLAY:%@", weakSelf.overlayController, weakSelf.overlay);
            [weakSelf.overlayController animateProgress:NO];
            [weakSelf.overlay performClose:weakSelf];
            [weakSelf.overlayController setText:@""];
        });
    }];
}

- (BOOL)modalOverlayShouldClose:(JMModalOverlay *)modalOverlay
{
    return YES;
}

- (void)modalOverlayWillClose:(NSNotification *)notification
{
    DLog(@"COCOAPODUI::OVERLAY_WILL_CLOSE");
}

- (void)modalOverlayDidClose:(NSNotification *)notification
{
    DLog(@"COCOAPODUI::InstallFinished");
    [self setChanged:!self.installationSucceded];
    if (self.needReopenWorkspace && self.installationSucceded) {
        DLog(@"COCOAPODUI::NowReopen");
        [self reopenProject:XCodeWorkspace];
    }
    else if (!self.installationSucceded) {
        DLog(@"NEED REOPEN, BUT INSTALL UNSUCCESFULL");
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

- (void)installTask:(PodTask)type completion:(void(^)(BOOL, NSError*))success
{
    NSParameterAssert((type == kUpdateTaskName)||(type == kInstallTaskName));
    
    NSTask *installTask = [[NSTask alloc] init];
    NSArray *args = type == kInstallTaskName ? @[@"install"] : @[@"update"];
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
    [output setReadabilityHandler:^(NSFileHandle *fileHandler) {
        NSData *data = [fileHandler availableData]; // this will read to EOF, so call only once
        NSString *text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        if ([text rangeOfString:@"[!] From now on use"].location == NSNotFound || [text rangeOfString:@"Integrating client project"].location == NSNotFound) {
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
        DLog(@"COCOAPODUI::INSTALLATION TERMINATION HANDLER");
        if (success != nil) {
            DLog(@"COCOAPODUI::WILL_PERFORM_INSTALSUCCESS_BLOCK");
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
    NSMutableString *result = [NSMutableString string];
    
    NSString *header = [NSString stringWithFormat:@"platform :%@, '%@'\n", [[self.platformName lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""], self.platformVersion];
    [result appendString:header];
    
    __block BOOL targetIsOpen = NO;
    [self.installedPods enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            if (targetIsOpen) {
                [result appendString:@"\nend\n"];
                targetIsOpen = NO;
            }
            [result appendFormat:@"\ntarget '%@' do", obj];
            targetIsOpen = YES;
        }
        else if ([obj isKindOfClass:[PodItem class]]) {
            PodItem *item = obj;
            NSMutableString *podString = [NSMutableString stringWithFormat:@"%@pod '%@'", idx == 0 ? @"" : @"\n", item.name];
            NSString *vMod = item.versionModifier;
            (([vMod length] == 0) || [vMod isEqualToString:kVersionModeEquals] || [vMod isEqualToString:kVersionModeEmpty]) ? [podString appendFormat:@", '%@'", item.version] : [podString appendFormat:@", '%@ %@'", vMod, item.version];
            NSString *git = [[item gitURL] absoluteString];
            if (git) {
                [podString appendFormat:@", :git => '%@'", git];
            }
            NSString *commit = [item commit];
            if (commit) {
                [podString appendFormat:@", :commit => '%@'", commit];
            }
            NSString *path = [item path];
            if (path) {
                [podString appendFormat:@":path => '%@'", path];
            }
            NSString *podspec = [[item podspecURL] absoluteString];
            if (podspec) {
                [podString appendFormat:@", :podspec => '%@'", podspec];
            }
            [result appendString:podString];
        }
    }];
    if (targetIsOpen) {
        [result appendString:@"\nend\n"];
        targetIsOpen = NO;
    }
    
    NSRange hookRange;
    if ([_parser hasPreinstallHook]) {
        NSString *preinstall = [_parser preinstallHook:&hookRange];
        if (preinstall) {
            [result appendFormat:@"\n%@", preinstall];
        }
    }
    if ([_parser hasPostinstallHook]) {
        NSString *postinstall = [_parser postinstallHook:&hookRange];
        if (postinstall) {
            [result appendFormat:@"\n%@", postinstall];
        }
    }
    
    return [NSString stringWithString:result];
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
        return @[@"4.3", @"5.0", @"5.1", @"6.0", @"6.1", @"7.0", @"7.1"];
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
        DLog(@"COCOAPODUI::REOPEN %lu - %@", (unsigned long)idx, controller);
        if ([[controller valueForKey:@"window"] isMainWindow]) {
            id workspaceDocument = [[controller valueForKey:@"window"] document];
            DLog(@"COCOAPODUI::REOPEN_DOCUMENT -- %@", workspaceDocument);
            NSString *projectFolderPath = [weakSelf.path stringByDeletingLastPathComponent];
            NSString *projectName = [(MainWindowController*)[[weakSelf.view window] windowController] projectName];
            NSString *extension = type == XCodeProject ? @"xcodeproj" : @"xcworkspace";
            NSString *workspaceFilePath = [projectFolderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", projectName, extension]];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:workspaceFilePath];
            DLog(@"INSTALL TO %@\nFILE EXIST = %d", workspaceFilePath,fileExists);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [workspaceDocument close];
                if (fileExists) {
                    NSTask *openTask = [[NSTask alloc] init];
                    NSArray *args = @[workspaceFilePath];
                    [openTask setLaunchPath:@"/usr/bin/open"];
                    [openTask setArguments:args];
                    DLog(@"%@", openTask);
                    [openTask launch];
                }
                else {
                    DLog(@"COCOAPODUI::START_TIMER");
                    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:.5 target:weakSelf selector:@selector(checkIfWorkspaceCreated:) userInfo:@{@"path":workspaceFilePath} repeats:YES];
#pragma unused (timer)
                }
            });
            
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
    if ([self savePodfile]) {
        if (![self.overlay isShown]) {
            [self.overlayController.taskLable setStringValue:@"Installing selected Pods..."];
            [self.overlayController animateProgress:YES];
            [self.overlay setTask:kInstallTaskName];
            [self.overlay showInWindow:[[self view] window]];
        }
    }
}

- (BOOL)savePodfile
{
    NSString *podfileString = [self podfileString];
//    DLog(@"PODFILE::%@", podfileString);
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
    BOOL saveSuccess = [podfileString writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (saveSuccess && !error) {
        _parser = [PodfileParser parserWithContentsOfFile:self.path];
        return YES;
    }
    return NO;
}

- (IBAction)closeAction:(id)sender
{
    [[[self view] window] close];
    [NSApp endSheet:[[self view] window]];
}

- (IBAction)deleteAllPods:(id)sender
{
    /*NSUInteger headerLastIndex = [self.podfileText rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location;
    if (headerLastIndex != NSNotFound) {
        [self.podfileText deleteCharactersInRange:NSMakeRange(headerLastIndex + 2, self.podfileText.length - headerLastIndex - 2)];
    }*/
    NSRange rng;
    NSString *platformLine = [_parser platformLine:&rng];
    
    // Clean up pods
    NSError *error = nil;
    NSString *projectFolderPath = [self.path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
    [platformLine writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
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

- (IBAction)deleteTarget:(id)sender
{
    NSString *targetName = [(NSTableCellView*)[sender superview] objectValue];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert setMessageText:[NSString stringWithFormat:@"Deleting of target \"%@\"", targetName]];
    [alert setInformativeText:[NSString stringWithFormat:@"Are you sure to delete target \"%@\" and all of dependent pods? This action can not be undone.", targetName]];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        switch (returnCode) {
            case 1001: {
                NSUInteger targetIndex = [weakSelf.installedPods indexOfObject:targetName];
                NSMutableArray *toRemove = [NSMutableArray array];
                [toRemove addObject:targetName];
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(targetIndex + 1, [weakSelf.installedPods count] - targetIndex - 1)];
                [weakSelf.installedPods enumerateObjectsAtIndexes:indexes options:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([obj isKindOfClass:[PodItem class]]) {
                        [toRemove addObject:obj];
                    }
                    else {
                        *stop = YES;
                    }
                }];
                NSUInteger lastIndex = [weakSelf.installedPods indexOfObject:[toRemove lastObject]];
                [weakSelf.installedPods removeObjectsInArray:toRemove];
                [weakSelf savePodfile];
                NSIndexSet *removeSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(targetIndex, lastIndex - targetIndex + 1)];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.installedTable removeRowsAtIndexes:removeSet withAnimation:NSTableViewAnimationSlideRight];
                    [weakSelf setChanged:YES];
                });
                break;
            }
            default:break;
        }
    }];
}

- (IBAction)addTarget:(id)sender
{
    NSAlert *addTargetAlert = [[NSAlert alloc] init];
    [addTargetAlert setAlertStyle:NSInformationalAlertStyle];
    NSString *projectName = [[[self.view window] windowController] projectName];
    [addTargetAlert setMessageText:[NSString stringWithFormat:@"Add new target to project \"%@\"", projectName]];
    [addTargetAlert setInformativeText:[NSString stringWithFormat:@"Define name for new target of project \"%@\"", projectName]];
    
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 20)];
    [[field cell] setPlaceholderString:@"Target name"];
    [field setTag:kAccessoryViewFieldTag];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [field setDelegate:self];

    [addTargetAlert setAccessoryView:field];
    [addTargetAlert addButtonWithTitle:@"Cancel"];
    [addTargetAlert addButtonWithTitle:@"Save"];
    NSButton *saveButton = [[addTargetAlert buttons] lastObject];
    [saveButton setEnabled:NO];
    [saveButton setTag:kSaveButtonTag];
    __weak typeof(self) weakSelf = self;
    [addTargetAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        switch (returnCode) {
            case kSaveButtonTag: {
                NSString *targetName = [field stringValue];
                [weakSelf.installedPods addObject:targetName];
                [weakSelf savePodfile];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.installedTable insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:[weakSelf.installedPods count]-1] withAnimation:NSTableViewAnimationSlideRight];
                    [weakSelf setChanged:YES];
                });
            }
            default:break;
        }
    }];
}

- (IBAction)switchOutdatedCheck:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id savedNeedShow = [defaults valueForKey:kNeedShowOutdatedPodsCount];
    if (!savedNeedShow && !self.needOutdatedCounter) {
        [self setNeedOutdatedCounter:self.needCheckOutdated];
    }
    [defaults setBool:self.needCheckOutdated forKey:kNeedCheckOutdatedPods];
    [defaults setBool:self.needOutdatedCounter forKey:kNeedShowOutdatedPodsCount];
    [defaults synchronize];
    
    if (self.needCheckOutdated) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSTask *outdatedTask = [[NSTask alloc] init];
            NSString *launchPath = [[NSUserDefaults standardUserDefaults] valueForKey:kPodGemPathKey];
            [outdatedTask setLaunchPath:launchPath];
            [outdatedTask setArguments:@[@"outdated"]];
            NSString *dirPath = [weakSelf.path stringByDeletingLastPathComponent];
            [outdatedTask setCurrentDirectoryPath:dirPath];
           
            NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
            environment[@"LC_ALL"]=@"en_US.UTF-8";
            [outdatedTask setEnvironment:environment];
            
            NSPipe *pipeOut = [NSPipe pipe];
            [outdatedTask setStandardOutput:pipeOut];
            NSFileHandle *output = [pipeOut fileHandleForReading];
            
            __block NSUInteger outdatedCounter = 0;
            [output setReadabilityHandler:^(NSFileHandle *fh) {
                NSData *data = [fh availableData];
                NSError *error = nil;
                NSDictionary *info = [YAMLSerialization objectWithYAMLData:data options:kYAMLReadOptionStringScalars error:&error];
                if ([info isKindOfClass:[NSDictionary class]]) {
                    NSArray *items = [[info allValues] firstObject];
                    [items enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                        NSRange whitespaceRange = [obj rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
                        if (whitespaceRange.location != NSNotFound) {
                            NSString *availableName = [obj substringToIndex:whitespaceRange.location];
                            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name BEGINSWITH %@", availableName];
                            PodItem *item = [[weakSelf.installedPods filteredArrayUsingPredicate:predicate] firstObject];
                            if (item) {
                                [item setOutdated:YES];
                                [weakSelf setHasOutdated:YES];
                                outdatedCounter++;
                            }
                        }
                    }];
                }
            }];
            
            [outdatedTask setTerminationHandler:^(NSTask *t) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.installedTable reloadData];
                    [weakSelf.updateButton setEnabled:(outdatedCounter > 0)];
                    if (weakSelf.needOutdatedCounter) {
                        NSString *title = [[NSApp mainWindow] title];
                        NSUInteger whitespace = [title rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location;
                        if (whitespace != NSNotFound) {
                            NSString *key = [title substringToIndex:whitespace];
                            [weakSelf.outdatedSheet setValue:@(outdatedCounter) forKey:key];
                            [[NSApp dockTile] setBadgeLabel: outdatedCounter > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)outdatedCounter] : nil];
                        }
                    }
                });
            }];
            
            [outdatedTask launch];
        });
    }
}

- (IBAction)switchOutdatedBadge:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:self.needOutdatedCounter forKey:kNeedShowOutdatedPodsCount];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSArray *outdated = [self.installedPods filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.outdated == 1"]];
    [[NSApp dockTile] setBadgeLabel: [sender state] > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)[outdated count]] : nil];
}

- (IBAction)updatePods:(id)sender
{
    if ([self savePodfile]) {
        if (![self.overlay isShown]) {
            [self.overlayController.taskLable setStringValue:@"Updating Pods..."];
            [self.overlayController animateProgress:YES];
            [self.overlay setTask:kUpdateTaskName];
            [self.overlay showInWindow:[[self view] window]];
        }
    }
}

#pragma mark
#pragma mark Text Delegate

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSTextField *field = [obj object];
    NSButton *saveButton = [[[field superview] superview] viewWithTag:kSaveButtonTag];
    [saveButton setEnabled:([[field stringValue] length] > 0)];
}

#pragma mark
#pragma mark Memory

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_reposReadStateObserver];
    _reposReadStateObserver = nil;
}
@end
