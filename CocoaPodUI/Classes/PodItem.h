//
//  PodItem.h
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
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

#import <Foundation/Foundation.h>

extern NSString *const kAddPodNotificationName;
extern NSString *const kDeletePodNotificationName;
extern NSString *const kEditPodNotificationName;

static NSString *const kVersionModeEmpty = @" ";
static NSString *const kVersionModeEquals = @"=";
static NSString *const kVersionModeUpToMajor = @"~>";
static NSString *const kVersionModeAnyHigher = @">";
static NSString *const kVersionModeIncludeAndHigher = @">=";
static NSString *const kVersionModeAnyLower = @"<";
static NSString *const kVersionModeIncludeAndLower = @"<=";

@interface PodItem : NSObject
- (instancetype)initWithPath:(NSString*)repoPath;
//- (void)setPodspecData:(NSData*)data;
@property (readonly, nonatomic) NSString *repoPath;
@property (copy, nonatomic) NSString *summary;
@property (copy, nonatomic) NSString *version;
@property (copy, nonatomic) NSString *versionModifier;
@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSArray *versions;
@property (copy, nonatomic) NSURL *gitURL;
@property (copy, nonatomic) NSString *commit;
@property (copy, nonatomic) NSURL *podspecURL;
@property (copy, nonatomic) NSString *path;
@property (assign, nonatomic) BOOL outdated;
@end
