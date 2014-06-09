//
//  JMModalOverlay+Task.h
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 09.06.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "JMModalOverlay.h"
#import "PodTask.h"
@interface JMModalOverlay (Task)
- (PodTask)task;
- (void)setTask:(PodTask)task;
@end
