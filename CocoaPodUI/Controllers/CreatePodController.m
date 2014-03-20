//
//  CreatePodController.m
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
