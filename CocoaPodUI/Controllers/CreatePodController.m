//
//  CreatePodController.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 01.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "CreatePodController.h"

@interface CreatePodController ()
@property (readonly) NSArray *versions;
- (IBAction)cancelAction:(id)sender;
- (IBAction)saveAction:(id)sender;
@end

@implementation CreatePodController

- (id)init
{
    self = [super initWithNibName:@"CreatePodController" bundle:[NSBundle bundleForClass:[self class]]];
    [self setPlatformName:@"iOS"];
    [self setPlatformVersion:@"4.3"];
    return self;
}

- (IBAction)cancelAction:(id)sender
{
    [[[self view] window] close];
    [NSApp endSheet:[[self view] window]];
}

- (IBAction)saveAction:(id)sender
{
    NSString *text = [NSString stringWithFormat:@"platform :%@, '%@'\n", [[self.platformName lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""], self.platformVersion];
    NSError *error = nil;
    [text writeToFile:self.path atomically:YES encoding:NSASCIIStringEncoding error:&error];
    if (!error) {
        if (self.podCreatedBlock != nil) {
            self.podCreatedBlock(self.platformName, self.platformVersion);
        }
    }
}

- (void)setPlatformName:(NSString *)platformName
{
    [self willChangeValueForKey:@"versions"];
    _platformName = platformName;
    [_platformName isEqualToString:@"iOS"] ? [self setPlatformVersion:@"4.3"] : [self setPlatformVersion:@"10.5"];
    [self didChangeValueForKey:@"versions"];
}

- (NSArray *)versions
{
    if ([self.platformName isEqualToString:@"iOS"]) {
        return @[@"4.3", @"5.0", @"6.0", @"7.0"];
    }
    else {
        return @[@"10.5", @"10.6", @"10.7", @"10.8", @"10.9"];
    }
}
@end
