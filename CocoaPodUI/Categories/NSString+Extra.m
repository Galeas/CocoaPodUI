//
//  NSString+Extra.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 03.04.14.
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