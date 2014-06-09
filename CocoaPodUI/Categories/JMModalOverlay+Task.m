//
//  JMModalOverlay+Task.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 09.06.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "JMModalOverlay+Task.h"
#import <objc/runtime.h>
@implementation JMModalOverlay (Task)

- (void)setTask:(PodTask)task
{
    objc_setAssociatedObject(self, "_taskname_", @(task), OBJC_ASSOCIATION_ASSIGN);
}

- (PodTask)task
{
    return [objc_getAssociatedObject(self, "_taskname_") unsignedIntegerValue];
}

@end
