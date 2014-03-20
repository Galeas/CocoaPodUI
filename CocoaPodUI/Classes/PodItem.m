//
//  PodItem.m
//  CocoaPodUI
//
//  Created by Евгений Кратько on 27.02.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import "PodItem.h"

@interface NSString (Extra)
- (NSString*)stringBetweenString:(NSString *)first andString:(NSString *)second;
@end
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
@end

@interface PodItem()
@property (copy) void(^_completion)(void);
@end

@implementation PodItem

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        [self setInstallString:string];
        NSCharacterSet *quoteSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
        NSScanner *scanner = [[NSScanner alloc] initWithString:string];
        [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"~>"]];
        while ([scanner isAtEnd] == NO) {
            NSString *name = nil;
            [scanner scanUpToCharactersFromSet:quoteSet intoString:NULL];
            [scanner setScanLocation:[scanner scanLocation] + 1];
            [scanner scanUpToCharactersFromSet:quoteSet intoString:&name];
            [self setName:name];
            
            NSString *version = nil;
            [scanner setScanLocation:[scanner scanLocation] + 1];
            [scanner scanUpToCharactersFromSet:quoteSet intoString:NULL];
            if ([scanner isAtEnd]) break;
            [scanner setScanLocation:[scanner scanLocation] + 1];
            [scanner scanUpToCharactersFromSet:quoteSet intoString:&version];
            [self setVersion:[NSString stringWithFormat:@"%@",[version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]]];
            break;
        }
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        NSString *possibleName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([possibleName rangeOfString:@" "].location != NSNotFound) {
            return nil;
        }
        else if ([possibleName rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location == NSNotFound) {
            return nil;
        }
        [self setName:possibleName];
    }
//    [self loadDescription];
    return self;
}

- (void)loadDescription
{
    [self loadDescriptionWithCompletion:nil];
}

- (void)loadDescriptionWithCompletion:(void (^)(void))completion
{
    [self set_completion:completion];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *podInfoTask = [[NSTask alloc] init];
        NSArray *args = @[@"search", weakSelf.name, @"--stats"];
        [podInfoTask setLaunchPath:@"/usr/bin/pod"];
        [podInfoTask setArguments:args];
        NSPipe *pipeOut = [NSPipe pipe];
        [podInfoTask setStandardOutput:pipeOut];
        NSFileHandle *output = [pipeOut fileHandleForReading];
        NSMutableDictionary * environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
        environment[@"LC_ALL"]=@"en_US.UTF-8";
        [podInfoTask setEnvironment:environment];
        [podInfoTask launch];
        NSData *data = [output readDataToEndOfFile];
        
        NSString *list = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSUInteger startIndex = [list rangeOfString:[NSString stringWithFormat:@"-> %@ ", weakSelf.name] options:NSLiteralSearch].location;
        if (startIndex != NSNotFound) {
            NSString *info = [list substringFromIndex:startIndex];
            NSArray *strings = [info componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSString *first = [strings objectAtIndex:0];
            NSUInteger versionIndex = [first rangeOfString:@" " options:NSBackwardsSearch].location;
            NSUInteger lastIndex = NSNotFound;
            if (versionIndex != NSNotFound) {
                lastIndex = [first rangeOfString:@")" options:NSBackwardsSearch].location;
            }
            NSString *version = versionIndex != NSNotFound ? [first substringWithRange:NSMakeRange(versionIndex + 2, lastIndex - versionIndex - 2)] : nil;
//            NSString *version = versionIndex != NSNotFound ? [first substringWithRange:NSMakeRange(versionIndex + 1, lastIndex - versionIndex/* + 1*/)] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf willChangeValueForKey:@"podDescription"];
                [weakSelf willChangeValueForKey:@"installString"];
                [weakSelf willChangeValueForKey:@"version"];
                [weakSelf willChangeValueForKey:@"availableVersions"];
                [weakSelf setVersion:version];
                [weakSelf setPodDescription:[[strings objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                [weakSelf setInstallString:[[strings objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                NSString *versionsString = [info stringBetweenString:@"- Versions: " andString:@"[master repo]"];
                if ([versionsString length] > 0) {
                    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"([0-9].)*?(\\S+[0-9])" options:NSRegularExpressionCaseInsensitive error:NULL];
                    NSMutableArray *arr = [NSMutableArray array];
                    [regex enumerateMatchesInString:versionsString options:0 range:NSMakeRange(0, versionsString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                        NSString *vStrng = [versionsString substringWithRange:result.range];
                        [arr addObject:vStrng];
                    }];
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    NSAssert(strongSelf, @"%s\tInstance already released!", __PRETTY_FUNCTION__);
                    if (strongSelf != nil) {
                        strongSelf->_availableVersions = [[NSArray arrayWithArray:arr] copy];
                    }
                }
                [weakSelf didChangeValueForKey:@"version"];
                [weakSelf didChangeValueForKey:@"podDescription"];
                [weakSelf didChangeValueForKey:@"installString"];
                [weakSelf didChangeValueForKey:@"availableVersions"];
                
                if (weakSelf._completion != nil) {
                    weakSelf._completion();
                }
            });
        }
    });
}

- (NSString *)installStringWithVersion:(NSString *)version
{
    return [NSString stringWithFormat:@"pod '%@', '~> %@'", self.name, version];
}

#pragma mark
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    PodItem *copyItem = [[PodItem alloc] init];
    
    [copyItem setName:[self.name copyWithZone:zone]];
    [copyItem setInstallString:[self.installString copyWithZone:zone]];
    [copyItem setPodDescription:[self.podDescription copyWithZone:zone]];
    [copyItem setVersion:[self.version copyWithZone:zone]];
    [copyItem setIOSSupport:self.iOSSupport];
    [copyItem setOSXSupport:self.OSXSupport];
    [copyItem setInProgress:self.inProgress];
    
    return copyItem;
}

- (BOOL)isEqualToPod:(PodItem *)pod
{
    BOOL equalNames = [self.name isEqualToString:pod.name];
    BOOL equalVersion = [self.version isEqualToString:pod.version];
    BOOL equalPlatform = (self.iOSSupport == pod.iOSSupport) && (self.OSXSupport == pod.OSXSupport);
    return equalNames && equalVersion && equalPlatform;
}

@end
