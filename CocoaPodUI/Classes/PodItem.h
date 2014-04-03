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

@interface PodItem : NSObject <NSCopying>
- (void)setPodspecData:(NSData*)data;
@property (strong, nonatomic) NSString *repoPath;
@property (strong, nonatomic) NSString *summary;
@property (strong, nonatomic) NSString *version;
@property (strong, nonatomic) NSString *versionModifier;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSArray *versions;
@end
