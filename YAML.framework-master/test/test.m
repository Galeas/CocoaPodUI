//
//	test.m
//	YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//
//	Copyright 2010 Mirek Rusin, Released under MIT License
//

#import <Foundation/Foundation.h>
#import "YAMLSerialization.h"

int
test (int argc, char *argv[]) {
    int result = 0;

	DLog(@"reading test file... ");
	NSData *data = [NSData dataWithContentsOfFile: @"yaml/basic.yaml"];
	NSInputStream *stream = [[[NSInputStream alloc] initWithFileAtPath: @"yaml/basic.yaml"] autorelease];
	DLog(@"done.");

	NSTimeInterval before = [[NSDate date] timeIntervalSince1970];
	NSMutableArray *yaml = [YAMLSerialization objectsWithYAMLData: data options: kYAMLReadOptionStringScalars error: nil];
	DLog(@"YAMLWithData took %f", ([[NSDate date] timeIntervalSince1970] - before));
	DLog(@"%@", yaml);

    NSError *err = nil;
	NSTimeInterval before2 = [[NSDate date] timeIntervalSince1970];
	NSMutableArray *yaml2 = [YAMLSerialization objectsWithYAMLStream: stream options: kYAMLReadOptionStringScalars error: &err];
	DLog(@"YAMLWithStream took %f", ([[NSDate date] timeIntervalSince1970] - before2));
	DLog(@"%@", yaml2);

    err = nil;
	NSTimeInterval before3 = [[NSDate date] timeIntervalSince1970];
	NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
	[YAMLSerialization writeObject: yaml toYAMLStream: outStream options: kYAMLWriteOptionMultipleDocuments error: &err];
	if (err) {
		DLog(@"Error: %@", err);
		return -1;
	}
	DLog(@"writeYAML took %f", (float) ([[NSDate date] timeIntervalSince1970] - before3));
	DLog(@"out stream %@", outStream);

	NSTimeInterval before4 = [[NSDate date] timeIntervalSince1970];
	NSData *outData = [YAMLSerialization YAMLDataWithObject: yaml2 options: kYAMLWriteOptionMultipleDocuments error: &err];
	if (!outData) {
		DLog(@"Data is nil!");
		return -1;
	}
	DLog(@"dataFromYAML took %f", ([[NSDate date] timeIntervalSince1970] - before4));
	DLog(@"out data %@", outData);

    return result;
}

int
main (int argc, char *argv[]) {
    int result = 0;
    @autoreleasepool {
        result = test(argc, argv);
    }
	return result;
}