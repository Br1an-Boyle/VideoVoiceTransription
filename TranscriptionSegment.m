//
//  TranscriptionSegment.m
//  VideoVAM
//
//  Created by Brian Boyle on 21/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import "TranscriptionSegment.h"

@implementation TranscriptionSegment

- (instancetype)initWithText:(NSString *)text timestamp:(NSTimeInterval)timestamp {
    self = [super init];
    if (self) {
        _text = text;
        _timestamp = timestamp;
    }
    return self;
}

@end
