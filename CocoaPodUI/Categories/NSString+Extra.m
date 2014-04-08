//
//  NSString+Extra.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 03.04.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "NSString+Extra.h"

@implementation NSString (Extra)

- (NSString *)stringBetweenString:(NSString *)first andString:(NSString *)second
{
    NSScanner* scanner = [NSScanner scannerWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:first intoString:NULL];
    if ([scanner scanString:first intoString:NULL]) {
        NSString* result = nil;
        if ([scanner scanUpToString:second intoString:&result]) {
            return result;
        }
    }
    return nil;
}

- (NSString *)stringBetweenString:(NSString *)first andString:(NSString *)second inRange:(NSRange)range
{
    NSString *substring = [self substringWithRange:range];
    return [substring stringBetweenString:first andString:second];
}

- (NSString *)stringByreplacingOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replacement
{
    NSRange range;
    NSString *s = [self copy];
    while ((range = [s rangeOfCharacterFromSet:set]).location != NSNotFound) {
        s = [s stringByReplacingCharactersInRange:range withString:replacement];
    }
    return s;
}
@end