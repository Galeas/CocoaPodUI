//
//  NSObject+IDEKit.h
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (IDEKit)
+ (NSArray*)workspaceWindowControllers;
- (void)close;
@end
