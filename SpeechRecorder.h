//
//  SpeechRecorder.h
//  VideoVAM
//
//  Created by Brian Boyle on 21/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpeechRecorder : NSObject


@property (nonatomic, strong) NSString *subtitlesPath;
- (void)startRecordingSpeech;
- (void)stopRecordingSpeech;

@end
