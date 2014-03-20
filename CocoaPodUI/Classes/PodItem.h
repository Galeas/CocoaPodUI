//
//  PodItem.h
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PodItem : NSObject <NSCopying>
- (instancetype)initWithString:(NSString*)string;
- (instancetype)initWithName:(NSString*)name;
- (void)loadDescription;
- (void)loadDescriptionWithCompletion:(void(^)(void))completion;
- (BOOL)isEqualToPod:(PodItem*)pod;
- (NSString*)installStringWithVersion:(NSString*)version;
@property (copy) NSString *name;
@property (copy) NSString *version;
@property (copy) NSString *podDescription;
@property (copy) NSString *installString;
@property (readonly) NSArray *availableVersions;
@property (assign, nonatomic) BOOL iOSSupport;
@property (assign, nonatomic) BOOL OSXSupport;
@property (assign, nonatomic) BOOL inProgress;
@end
