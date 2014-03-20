//
//  NSWindow+Sizing.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 01.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

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
    // Since window origin is at the bottom, and we want
    // the bottom to move instead of the top, we also
    // adjust the origin.y.  However, since screen y is
    // measured from the top, we must subtract instead of add
    frameW.origin.y -= dY ;
    
    [self setFrame:frameW display:display] ;
}

@end
