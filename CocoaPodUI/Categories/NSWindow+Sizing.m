//
//  NSWindow+Sizing.m
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

#import "NSWindow+Sizing.h"

@implementation NSWindow (Sizing)

- (void)setFrameToFitContentViewDisplay:(BOOL)display {
    NSRect frameW = NSMakeRect(0,0,255,255) ;
    NSRect frameC = [self contentRectForFrameRect:frameW] ;
    float titleToolBarHeight = frameW.size.height - frameC.size.height ;
    
    frameC = [[self contentView] frame] ;
    frameW = [self frame] ;
    
    float newHeight = frameC.size.height + titleToolBarHeight ;
    float dY = newHeight - frameW.size.height ;
    
    frameW.size.width = frameC.size.width ;
    frameW.size.height = newHeight ;
    frameW.origin.y -= dY ;
    
    [self setFrame:frameW display:display] ;
}

@end
