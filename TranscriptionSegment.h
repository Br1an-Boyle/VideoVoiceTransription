//
//  TranscriptionSegment.h
//  VideoVAM
//
//  Created by Brian Boyle on 21/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TranscriptionSegment : NSObject

@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) NSTimeInterval timestamp;

- (instancetype)initWithText:(NSString *)text timestamp:(NSTimeInterval)timestamp;
@end
