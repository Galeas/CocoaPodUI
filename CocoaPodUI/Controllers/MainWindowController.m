//
//  MainWindowController.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "MainWindowController.h"
#import "CreatePodController.h"
#import "PodsManagementViewController.h"
#import "PodItem.h"

#import "NSObject+IDEKit.h"
#import "NSWindow+Sizing.h"

@interface MainWindowController () <NSWindowDelegate, NSTableViewDelegate>
@property (strong, nonatomic) NSString *projectFolderURLString;
@property (strong, nonatomic) CreatePodController *createPodController;
@property (strong, nonatomic) PodsManagementViewController *managementController;
@property (assign, nonatomic) BOOL isOSXProject;
@end

@implementation MainWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setBackgroundColor:RGB(245, 245, 245)];
}

#pragma mark

- (void)updateInfo
{
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
    __weak typeof(self) weakSelf = self;
    [workspaceWindowControllers enumerateObjectsUsingBlock:^(id controller, NSUInteger idx, BOOL *stop) {
        if ([[controller valueForKey:@"window"] isMainWindow]) {
            id workspace = [controller valueForKey:@"_workspace"];
            NSString *filePath = [[workspace valueForKey:@"representingFilePath"] valueForKey:@"pathString"];
            NSString *projectName = [[filePath lastPathComponent] stringByDeletingPathExtension];
            NSString *infoPlistPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@-Info.plist", projectName, projectName]];
            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
            if (infoPlist) {
                [weakSelf setIsOSXProject:[infoPlist valueForKey:@"NSPrincipalClass"] != nil];
            }
            NSString *text = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Podfile"];
            [weakSelf setProjectFolderURLString:text];
            [weakSelf checkPodfile];
            *stop = YES;
        }
    }];
}

- (void)checkPodfile
{
    if (!self.createPodController) {
        [self setCreatePodController:[[CreatePodController alloc] init]];
        [[self.createPodController view] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    }
    if (!self.managementController) {
        [self setManagementController:[[PodsManagementViewController alloc] init]];
        [[self.managementController view] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    }
    
    BOOL podfileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.projectFolderURLString];
    if (podfileExists) {
        [[self window] setContentView:[self.managementController view]];
        [self.managementController loadPodsWithPath:self.projectFolderURLString];
    }
    else {
        __weak typeof(self) weakSelf = self;
        [self.createPodController setPath:self.projectFolderURLString];
        self.isOSXProject ? [self.createPodController setPlatformName:@"OS X"] : [self.createPodController setPlatformName:@"iOS"];
        [self.createPodController setPodCreatedBlock:^(NSString *platform, NSString *version) {
            [[weakSelf window] setContentView:[weakSelf.managementController view]];
            [weakSelf.managementController loadPodsWithPath:weakSelf.projectFolderURLString];
        }];
        NSView *createPodView = [self.createPodController view];
        [[self window] setContentView:createPodView];
    }
}

@end
