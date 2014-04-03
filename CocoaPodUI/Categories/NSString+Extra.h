//
//  NSString+Extra.h
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 03.04.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Extra)
- (NSString*)stringBetweenString:(NSString *)first andString:(NSString *)second;
- (NSString*)stringBetweenString:(NSString *)first andString:(NSString *)second inRange:(NSRange)range;
@end
