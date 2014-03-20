//
//  CreatePodController.h
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 01.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CreatePodController : NSViewController
@property (copy) void(^podCreatedBlock)(NSString *platform, NSString *version);
@property (strong, nonatomic) NSString *path;
@property (copy, nonatomic) NSString *platformName;
@property (copy) NSString *platformVersion;
@end
