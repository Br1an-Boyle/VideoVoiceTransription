//
//  Subtitle.h
//  VideoVAM
//
//  Created by Brian Boyle on 21/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Subtitle : NSObject

@property (nonatomic, strong) NSString *sentence;
@property (nonatomic, strong) NSString *fromTime;
@property (nonatomic, strong) NSString *toTime;

@end
