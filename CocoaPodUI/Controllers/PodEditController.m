//
//  PodEditController.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 19.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "PodEditController.h"
#import "PodItem.h"

@interface PodEditController ()

@end

@implementation PodEditController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)setItem:(PodItem *)item
{
    if (_item) {
        @try {
            [_item removeObserver:self forKeyPath:@"version"];
        }
        @catch (NSException *exception) {
            NSLog(@"%@", [exception reason]);
        }
    }
    _item = item;
    [_item addObserver:self forKeyPath:@"version" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"version"]) {
        NSLog(@"POD CHANGE VERSION %s", __PRETTY_FUNCTION__);
        if ([self.delegate respondsToSelector:@selector(didCompletePodEdition:)]) {
            [self.delegate didCompletePodEdition:self.item];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)closeAction:(id)sender
{
    [[self window] close];
    [NSApp endSheet:[self window]];
}
@end
