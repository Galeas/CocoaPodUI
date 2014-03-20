//
//  PodsOverlayController.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 04.03.14.
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
