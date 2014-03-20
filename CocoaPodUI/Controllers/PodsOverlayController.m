//
//  PodsOverlayController.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 04.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "PodsOverlayController.h"

@interface PodsOverlayController ()
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@end

@implementation PodsOverlayController

- (id)init
{
    self = [super initWithNibName:@"PodsOverlayController" bundle:[NSBundle bundleForClass:[self class]]];
    return self;
}

- (void)animateProgress:(BOOL)animate
{
    animate ? [self.progressIndicator startAnimation:self] : [self.progressIndicator stopAnimation:self];
}

- (void)appendText:(NSString *)text
{
    NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:12], NSForegroundColorAttributeName:[NSColor whiteColor]}];
    [[self.textView textStorage] appendAttributedString:str];
}

- (void)setText:(NSString *)text
{
    NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:12], NSForegroundColorAttributeName:[NSColor whiteColor]}];
    [[self.textView textStorage] setAttributedString:str];
}

@end
