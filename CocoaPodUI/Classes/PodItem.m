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

@interface PodItem() <NSCopying, NSCoding>
@property (copy) void(^_completion)(PodItem*);
@property (readonly) NSArray *possibleVersionModifiers;
@end

@implementation PodItem

- (id)init
{
    self = [super init];
    if (self) {
        [self setOutdated:NO];
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)repoPath
{
    self = [super init];
    if (self) {
        [self setOutdated:NO];
        self->_repoPath = repoPath;
        self->_name = [[[repoPath lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
        self->_versionModifier = kVersionModeEquals;
        NSData *data = [NSData dataWithContentsOfFile:self->_repoPath];
        [[_repoPath pathExtension] isEqualToString:@"json"] ? [self setDataFromJSON:data] : [self setDataFromYAML:data];
    }
    return self;
}

- (void)setDataFromYAML:(NSData *)data
{
    NSAssert(data, @"PODSPEC DATA IS NULL, %s", __PRETTY_FUNCTION__);
    
    NSString *podspecString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSCharacterSet *restrictedSet = [NSCharacterSet characterSetWithCharactersInString:@" \t'\""];
    CGFloat lenght = [podspecString length];
    NSRange range;
    @try {
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

- (void)setDataFromJSON:(NSData*)data
{
    NSAssert(data, @"PODSPEC DATA IS NULL, %s", __PRETTY_FUNCTION__);
    
    NSError *error = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!error) {
        NSCharacterSet *restrictedSet = [NSCharacterSet characterSetWithCharactersInString:@" \t'\""];
        _version = [[info valueForKey:@"version"] stringByTrimmingCharactersInSet:restrictedSet];
        _summary = [[info valueForKey:@"summary"] stringByTrimmingCharactersInSet:restrictedSet];
//        _gitURL = [NSURL URLWithString:[[info valueForKeyPath:@"source.git"] stringByTrimmingCharactersInSet:restrictedSet]];
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
    return @[kVersionModeEmpty, kVersionModeEquals, kVersionModeUpToMajor, kVersionModeAnyHigher, kVersionModeIncludeAndHigher, kVersionModeAnyLower, kVersionModeIncludeAndLower];
}

#pragma mark
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    PodItem *copyItem = [super init];
    
    copyItem->_name = [self.name copyWithZone:zone];
    copyItem->_version = [self.version copyWithZone:zone];
    copyItem->_summary = [self.summary copyWithZone:zone];
    copyItem->_versionModifier = [self.versionModifier copyWithZone:zone];
    copyItem->_versions = [self.versions copyWithZone:zone];
//    copyItem->_repoPath = [self.repoPath copyWithZone:zone];
    copyItem->_commit = [self.commit copyWithZone:zone];
    copyItem->_gitURL = [self.gitURL copyWithZone:zone];
    copyItem->_podspecURL = [self.podspecURL copyWithZone:zone];
    copyItem->_path = [self.path copyWithZone:zone];
    copyItem->_outdated = self.outdated;
    
    return copyItem;
}

- (BOOL)isEqualToPod:(PodItem *)pod
{
    BOOL equalNames = [self.name isEqualToString:pod.name];
    BOOL equalVersion = [self.version isEqualToString:pod.version];
    return equalNames && equalVersion;
}

#pragma mark
#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        [self setName:[aDecoder decodeObjectForKey:@"name"]];
        [self setSummary:[aDecoder decodeObjectForKey:@"summary"]];
        [self setVersion:[aDecoder decodeObjectForKey:@"version"]];
        [self setVersions:[aDecoder decodeObjectForKey:@"versions"]];
        [self setVersionModifier:[aDecoder decodeObjectForKey:@"versionModifier"]];
//        [self setRepoPath:[aDecoder decodeObjectForKey:@"repoPath"]];
        [self setCommit:[aDecoder decodeObjectForKey:@"commit"]];
        [self setGitURL:[aDecoder decodeObjectForKey:@"gitURL"]];
        [self setPodspecURL:[aDecoder decodeObjectForKey:@"podspecURL"]];
        [self setPath:[aDecoder decodeObjectForKey:@"path"]];
        [self setOutdated:[[aDecoder decodeObjectForKey:@"outdated"] boolValue]];
        
        return self;
    }
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.summary forKey:@"summary"];
    [aCoder encodeObject:self.version forKey:@"version"];
    [aCoder encodeObject:self.versions forKey:@"versions"];
    [aCoder encodeObject:self.versionModifier forKey:@"versionModifier"];
//    [aCoder encodeObject:self.repoPath forKey:@"repoPath"];
    [aCoder encodeObject:self.commit forKey:@"commit"];
    [aCoder encodeObject:self.gitURL forKey:@"gitURL"];
    [aCoder encodeObject:self.podspecURL forKey:@"podspecURL"];
    [aCoder encodeObject:self.path forKey:@"path"];
    [aCoder encodeObject:@(self.outdated) forKey:@"outdated"];
}
@end
