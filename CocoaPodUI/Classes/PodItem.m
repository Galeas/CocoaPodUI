//
//  PodItem.m
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

#import "PodItem.h"
#import "NSString+Extra.h"

NSString *const kAddPodNotificationName = @"CocoaPodUI:AddPodAction";
NSString *const kDeletePodNotificationName = @"CocoaPodUI:DeletePodAction";
NSString *const kEditPodNotificationName = @"CocoaPodUI:EditPodAction";

@interface PodItem()
@property (copy) void(^_completion)(PodItem*);
@property (readonly) NSArray *possibleVersionModifiers;
@end

@implementation PodItem

- (void)setPodspecData:(NSData *)data
{
    NSParameterAssert(data);
    
    NSString *podspecString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSCharacterSet *restrictedSet = [NSCharacterSet characterSetWithCharactersInString:@" \t'\""];
    CGFloat lenght = [podspecString length];
    
    NSRange range;
    @try {
        range = [podspecString rangeOfString:@".name"];
        NSString *nameString = [podspecString stringBetweenString:@"=" andString:@"\n" inRange:NSMakeRange(range.location, lenght - range.location)];
        _name = [nameString stringByTrimmingCharactersInSet:restrictedSet];
        
        range = [podspecString rangeOfString:@".version"];
        NSString *versionString = [podspecString stringBetweenString:@"=" andString:@"\n" inRange:NSMakeRange(range.location, lenght - range.location)];
        _version = [versionString stringByTrimmingCharactersInSet:restrictedSet];
        
        range = [podspecString rangeOfString:@".summary"];
        NSString *summaryString = [podspecString stringBetweenString:@"=" andString:@"\n" inRange:NSMakeRange(range.location, lenght - range.location)];
        _summary = [summaryString stringByTrimmingCharactersInSet:restrictedSet];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", self.repoPath);
    }
}

- (void)addAction
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kAddPodNotificationName object:self];
}

- (void)editAction
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kEditPodNotificationName object:self];
}

- (void)deleteAction
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeletePodNotificationName object:self];
}

- (NSArray *)possibleVersionModifiers
{
    return @[@"Version logic", @"~>", @">", @">=", @"<", @"<="];
}

#pragma mark
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    PodItem *copyItem = [[PodItem alloc] init];
    
    copyItem->_name = [self.name copyWithZone:zone];
    copyItem->_version = [self.version copyWithZone:zone];
    copyItem->_summary = [self.summary copyWithZone:zone];
    copyItem->_versionModifier = [self.versionModifier copyWithZone:zone];
    copyItem->_versions = [self.versions copyWithZone:zone];
    copyItem->_repoPath = [self.repoPath copyWithZone:zone];
    
    return copyItem;
}

- (BOOL)isEqualToPod:(PodItem *)pod
{
    BOOL equalNames = [self.name isEqualToString:pod.name];
    BOOL equalVersion = [self.version isEqualToString:pod.version];
    return equalNames && equalVersion;
}
@end
