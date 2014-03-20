//
//  CocoaPodUI.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "CocoaPodUI.h"
#import "Controllers/MainWindowController.h"

#import "NSObject+IDEKit.h"

#define kMenuItemTag 666

@interface CocoaPodUI()
@property (strong, nonatomic) MainWindowController *windowController;
@end

@implementation CocoaPodUI

+ (void) pluginDidLoad: (NSBundle*) plugin {
	static id sharedPlugin = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
    }
    return self;
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification
{
    NSMenuItem* editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (editMenuItem) {
        [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem* newMenuItem = [[NSMenuItem alloc] initWithTitle:@"CocoaPod UI" action:@selector(showMessageBox:) keyEquivalent:@"c"];
        [newMenuItem setTarget:self];
        [newMenuItem setKeyEquivalentModifierMask:NSShiftKeyMask|NSControlKeyMask];
        [newMenuItem setTag:kMenuItemTag];
        [[editMenuItem submenu] addItem:newMenuItem];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem.tag == kMenuItemTag) {
        NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
        return [workspaceWindowControllers count] > 0;
    }
    return YES;
}

- (void)showMessageBox:(id)origin
{
    if (!self.windowController) {
        MainWindowController *controller = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
        [self setWindowController:controller];
    }
    [NSApp beginSheet:[self.windowController window] modalForWindow:[NSApp keyWindow] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
    [self.windowController updateInfo];
}

@end
