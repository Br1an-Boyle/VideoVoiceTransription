//
//  SpeechRecorder.m
//  VideoVAM
//
//  Created by Brian Boyle on 21/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import "SpeechRecorder.h"
@import Speech;
#import "TranscriptionSegment.h"
#import "Subtitle.h"

@interface SpeechRecorder ()
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechRecognitionTask *speechRecognitionTask;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *speechRecognitionRequest;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *inputNode;
@property (nonatomic, strong) NSMutableArray *transcriptionSegmentArray;
@end

@implementation SpeechRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
        _audioEngine = [AVAudioEngine new];
        _transcriptionSegmentArray = [NSMutableArray new];
    }
    [self requestSpeechAuthorisation];
    return self;
}

- (void)requestSpeechAuthorisation {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        NSLog(@"Speech Status : %ld", (long)status);
    }];
}

- (void)startRecordingSpeech {
    NSLog(@"Starting to record speech");
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeMeasurement error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    self.speechRecognitionRequest = [SFSpeechAudioBufferRecognitionRequest new];
    self.speechRecognitionRequest.shouldReportPartialResults = NO;
    self.inputNode = self.audioEngine.inputNode;
    
    self.speechRecognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.speechRecognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"ERROR recording speech : %@", error);
        }
        
        if (result) {
            for (SFTranscriptionSegment *transcriptionSegment in result.bestTranscription.segments) {
                NSLog(@"%f - %@", transcriptionSegment.timestamp, transcriptionSegment.substring);
                TranscriptionSegment *trans = [[TranscriptionSegment alloc] initWithText:transcriptionSegment.substring timestamp:transcriptionSegment.timestamp];
                [self.transcriptionSegmentArray addObject:trans];
            }
            NSArray<Subtitle *> *subtitleArray = [self sortTranscriptionSegments];
            NSString *subtitleContent = [self buildSubtitleContent:subtitleArray];
            [self saveSubtitleContent:subtitleContent];
        }
    }];
    
    AVAudioFormat *audioFormat = [self.inputNode outputFormatForBus:0];
    [self.inputNode installTapOnBus:0 bufferSize:1024 format:audioFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [self.speechRecognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:nil];
}

- (void)stopRecordingSpeech {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.speechRecognitionTask && self.speechRecognitionTask.state == SFSpeechRecognitionTaskStateRunning) {
            [self.inputNode removeTapOnBus:0];
            [self.inputNode reset];
            [self.speechRecognitionRequest endAudio];
            [self.audioEngine stop];
            [self.speechRecognitionTask cancel];
            self.speechRecognitionRequest = nil;
            self.speechRecognitionTask = nil;
        }
    });
}

- (NSArray<Subtitle *> *)sortTranscriptionSegments {
    NSInteger limit = 3;
    NSMutableArray<Subtitle *> *subtitleArray = [NSMutableArray<Subtitle *> new];
    Subtitle *subtitle = [Subtitle new];
    for (TranscriptionSegment *transSeg in self.transcriptionSegmentArray) {
        //NSLog(@"LIMIT : %ld",limit);
        
        
        if (transSeg.timestamp < limit) {
            subtitle.sentence = [subtitle.sentence stringByAppendingString:[NSString stringWithFormat:@" %@ ", transSeg.text]];
            
            
        } else {
            [self addSubtitle:subtitle timeLimit:limit toArray:subtitleArray];
            subtitle = [Subtitle new];
            limit = limit + 3;
        }
    }
    [self addSubtitle:subtitle timeLimit:limit toArray:subtitleArray];
    return subtitleArray;
}

- (void)addSubtitle:(Subtitle *)subtitle timeLimit:(NSInteger)limit toArray:(NSMutableArray *)subtitleArray {
    subtitle.fromTime = [NSString stringWithFormat:@"%ld", limit -3];
    subtitle.toTime = [NSString stringWithFormat:@"%ld", limit];
    [subtitleArray addObject:subtitle];
}

- (NSString *)buildSubtitleContent:(NSArray *)subtitleArray {
    NSString *content = @"WEBVTT FILE";
    
    NSInteger count = 1;
    for (Subtitle *subtitle in subtitleArray) {
        content = [content stringByAppendingString:[NSString stringWithFormat:@"\r\n\n%ld\r\n00:00:0%@.000 --> 00:00:0%@.000\r\n%@", count, subtitle.fromTime, subtitle.toTime, subtitle.sentence]];
    }
    return content;
}

- (void)saveSubtitleContent:(NSString *)content {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSUUID *uuid = [NSUUID UUID];
    self.subtitlesPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vtt", uuid]];
    NSLog(@"PAth : %@", self.subtitlesPath);
    BOOL canWrite = YES;
    if ([[NSFileManager defaultManager]  fileExistsAtPath:self.subtitlesPath]) {
        NSError *deleteError;
        NSLog(@"deleting previous recording");
        canWrite = [[NSFileManager defaultManager] removeItemAtPath:self.subtitlesPath error:&deleteError];
    }
    
    if (canWrite) {
        NSError *error;
        [content writeToFile:self.subtitlesPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    [self.transcriptionSegmentArray removeAllObjects];
}
@end
