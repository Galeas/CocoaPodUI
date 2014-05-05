//
//  CocoaPodUI.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
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

#import "CocoaPodUI.h"
#import "Controllers/MainWindowController.h"

#import "NSObject+IDEKit.h"
#import <YAMLSerialization.h>

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
        [self findGemLocation];
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

- (void)findGemLocation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *location = [defaults valueForKey:kPodGemPathKey];

    if ([location length] > 0) {
        if (![manager fileExistsAtPath:location]) {
            [defaults removeObjectForKey:kPodGemPathKey];
            [defaults synchronize];
            location = nil;
        }
    }
    if ([location length] == 0) {
        NSTask *sTask = [[NSTask alloc] init];
        [sTask setArguments:@[@"pod"]];
        [sTask setLaunchPath:@"/usr/bin/which"];
        NSPipe *pipeOut = [NSPipe pipe];
        [sTask setStandardOutput:pipeOut];
        NSFileHandle *output = [pipeOut fileHandleForReading];
        [sTask launch];
        NSData *data = [output readDataToEndOfFile];
        NSString *path = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([manager fileExistsAtPath:path]) {
            [defaults setValue:path forKeyPath:kPodGemPathKey];
            [defaults synchronize];
        }
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
