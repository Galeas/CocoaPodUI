//
//  PodEditController.h
//  CocoaPodUI
//
//  Created by Евгений Кратько on 19.03.14.
//  Copyright (c) 2014 akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class PodItem;

@protocol PodEdtitionDelegate <NSObject>
//- (NSString*)path;
- (void)didCompletePodEdition:(PodItem*)item;
@end

@interface PodEditController : NSWindowController
@property (strong, nonatomic) PodItem *item;
@property (weak) NSObject<PodEdtitionDelegate> *delegate;
- (IBAction)closeAction:(id)sender;
@end
