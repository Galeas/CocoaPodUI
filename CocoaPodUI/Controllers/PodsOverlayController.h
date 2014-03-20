//
//  PodsOverlayController.h
//  CocoaPodUI
//
//  Created by Евгений Кратько on 04.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PodsOverlayController : NSViewController
- (void)animateProgress:(BOOL)animate;
- (void)appendText:(NSString*)text;
- (void)setText:(NSString*)text;
@end
