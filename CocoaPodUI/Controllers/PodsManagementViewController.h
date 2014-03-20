//
//  PodsManagementViewController.h
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 01.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const kUserDidDeleteAllPods;

@interface PodsManagementViewController : NSViewController
@property (strong, nonatomic) NSMutableArray *installedPods;
@property (strong, nonatomic) NSArray *availablePods;
- (void)loadPodsWithPath:(NSString*)path;
@end
