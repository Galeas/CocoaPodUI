//
//  PodfileParser.m
//  CocoaPodUI
//
//  Created by Evgeniy Kratko on 15.04.14.
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

#import "PodfileParser.h"
#import "NSString+Extra.h"

@implementation PodfileParser

+ (instancetype)parserWithContentsOfFile:(NSString *)path
{
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (content && !error) {
        content = [content stringByreplacingOccurrencesOfCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"`\""] withString:@"'"];
        PodfileParser *instance = [[self alloc] init];
        instance->_content = content;
        return instance;
    }
    return nil;
}

- (NSString *)platformLine:(NSRange *)range
{
    NSRange lineRange = [_content rangeOfString:@"platform"];
    if (lineRange.location != NSNotFound) {
        NSRange searchRange = [_content rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSCaseInsensitiveSearch range:NSMakeRange(lineRange.location, [_content length] - lineRange.location)];
        NSRange platformRange = NSMakeRange(lineRange.location, searchRange.location - lineRange.location);
        NSString *platformLine = [_content substringWithRange:platformRange];
        *range = platformRange;
        return platformLine;
    }
    *range = NSMakeRange(NSNotFound, 0);
    return nil;
}

- (NSDictionary *)targetAtIndex:(NSUInteger)index
{
    if (([_content rangeOfString:@"target "].location != NSNotFound) || ([_content rangeOfString:@"target\t"].location != NSNotFound)) {
        __block NSInteger counter = -1;
        __block NSRange targetRange;
        __block BOOL targetInProgress = NO;
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [_content enumerateSubstringsInRange:NSMakeRange(0, [_content length]) options:NSStringEnumerationByLines usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            NSString *line = [substring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([line hasPrefix:@"target "] || [line hasPrefix:@"target\t"]) {
                counter++;
                if (counter == index) {
                    targetInProgress = YES;
                    NSString *name = [line stringBetweenString:@"'" andString:@"'"];
                    [dict setValue:name forKey:kPodfileTargetName];
                    targetRange.location = enclosingRange.location;
                }
            }
            else if ([line hasPrefix:@"end"] && targetInProgress) {
                targetInProgress = NO;
                targetRange.length = enclosingRange.location - targetRange.location;
                [dict setValue:[NSValue valueWithRange:targetRange] forKey:kPodfileTargetRange];
                *stop = YES;
            }
        }];
        return [[dict allKeys] count] > 0 ? [NSDictionary dictionaryWithDictionary:dict] : nil;
    }
    else {
        NSRange firstPodLineRange = [_content rangeOfString:@"pod"];
        if (firstPodLineRange.location != NSNotFound) {
            NSRange lastPodLineRange = [_content rangeOfString:@"pod" options:NSBackwardsSearch];
            NSRange eolRange = [_content rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSCaseInsensitiveSearch range:NSMakeRange(lastPodLineRange.location, [_content length] - lastPodLineRange.location)];
            NSRange podsRange = NSMakeRange(firstPodLineRange.location, eolRange.location != NSNotFound ? (eolRange.location - firstPodLineRange.location) : ([_content length] - firstPodLineRange.location));
            NSDictionary *dict = @{kPodfileTargetName:kPodfileDefaultTargetName, kPodfileTargetRange:[NSValue valueWithRange:podsRange]};
            return dict;
        }
    }
    return nil;
}

- (NSUInteger)targetCount
{
    __block NSUInteger count = 0;
    if ([_content rangeOfString:@"target"].location != NSNotFound) {
        [_content enumerateSubstringsInRange:NSMakeRange(0, [_content length]) options:NSStringEnumerationByLines usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            NSString *line = [substring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (([line hasPrefix:@"target "] || [line hasPrefix:@"target\t"]) && [line hasSuffix:@"do"]) {
                count++;
            }
        }];
    }
    else {
        return 1;
    }
    return count;
}

- (NSString*)hook:(NSString*)hook range:(NSRange*)range
{
    NSUInteger start = [_content rangeOfString:hook].location;
    __block NSRange rng = NSMakeRange(NSNotFound, 0);
    if (start != NSNotFound) {
        __block NSUInteger countr = 0;
        NSMutableString *result = [NSMutableString string];
        [_content enumerateSubstringsInRange:NSMakeRange(start, [_content length] - start) options:NSStringEnumerationByLines usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [result appendString:[_content substringWithRange:enclosingRange]];
            if ([substring rangeOfString:@" do"].location != NSNotFound) {
                countr++;
            }
            else if ([substring rangeOfString:@"end"].location != NSNotFound) {
                countr--;
            }
            if (countr == 0) {
                *stop = YES;
                rng = NSMakeRange(start, NSMaxRange(enclosingRange) - start);
            }
        }];
        *range = rng;
        return [NSString stringWithString:result];
    }
    *range = rng;
    return nil;
}

- (NSString *)preinstallHook:(NSRange *)range
{
    return [self hook:@"pre_install do" range:range];
}

- (NSString *)postinstallHook:(NSRange *)range
{
    return [self hook:@"post_install do" range:range];
}

- (BOOL)hasPreinstallHook
{
    return [_content rangeOfString:@"pre_install do"].location != NSNotFound;
}

- (BOOL)hasPostinstallHook
{
    return [_content rangeOfString:@"post_install do"].location != NSNotFound;
}

@end
