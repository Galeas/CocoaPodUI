//
//  JMModalOverlayView.m
//  JMModalOverlay
//
//  Copyright (c) 2013 Jérémy Marchand (http://www.kodlian.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "JMModalOverlayView.h"

@implementation JMModalOverlayView
- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setWantsLayer:YES];
        
    }
    return self;
}

#pragma mark -
#pragma mark background color
- (void)viewDidMoveToSuperview{
    
    [[self layer] setCornerRadius:4];
    [[self layer] setMasksToBounds:YES];
    [[self layer] setBorderWidth:0.5];
    
    [[self layer] setBorderColor:[[NSColor colorWithCalibratedWhite:1 alpha:0.2] CGColor]];


}

@end
