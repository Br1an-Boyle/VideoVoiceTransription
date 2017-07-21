//
//  ViewController.m
//  VideoVAM
//
//  Created by Brian Boyle on 20/07/2017.
//  Copyright © 2017 Brian Boyle. All rights reserved.
//

#import "ViewController.h"
#import "SpeechRecorder.h"
#import "PureLayout.h"

@import AVFoundation;
@import CoreMedia;
@import Speech;

@interface ViewController () <AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *cameraPreviewLayer;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) UIButton *captureVideoButton;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *timerLabel;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, strong) NSTimer *recordingCompletionTimer;
@property (nonatomic, strong) SpeechRecorder *speechRecorder;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

static NSString* const kVAMInfoMessage = @"Tap to record a Video Auto Message";
static NSString* const kVAMUploadingMessage = @"Uploading Video Auto Message...";

@implementation ViewController

- (void)loadView {
    [super loadView];
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    [self configureCameraPreview];
    self.speechRecorder = [SpeechRecorder new];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Video Auto Message";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view addSubview:self.captureVideoButton];
    [self.view addSubview:self.infoLabel];
    [self.view addSubview:self.timerLabel];
    self.timerLabel.hidden = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.captureVideoButton autoSetDimensionsToSize:CGSizeMake(68, 68)];
    [self.captureVideoButton autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.captureVideoButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.view withOffset:-60.f];
    
    [self.infoLabel autoSetDimensionsToSize:CGSizeMake(300, 30)];
    [self.infoLabel autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.infoLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.captureVideoButton withOffset:10.f];
    
    [self.timerLabel autoSetDimensionsToSize:CGSizeMake(50, 50)];
    [self.timerLabel autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.timerLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.captureVideoButton withOffset:-10.f];
}


#pragma mark - Camera

- (void)configureCameraPreview {
    self.session = [AVCaptureSession new];
    // Starting the camera on iOS 10 simulators will cause it to crash
    [self.session setSessionPreset:AVCaptureSessionPresetHigh];
    
    
    NSError *error;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"profile_connecting_camera_error_title", nil)
                                                                   message:NSLocalizedString(@"profile_connecting_camera_error_message", nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ACK_ERROR", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [alert dismissViewControllerAnimated:YES completion:nil];
                                            }]];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[self frontCamera] error:&error];
    if (error) {
        [self presentViewController:alert animated:YES completion:nil];
        self.session = nil;
        return;
    }
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
    }
    
    // Add audio input.
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if ( ! audioDeviceInput ) {
        NSLog( @"Could not create audio device input: %@", error );
    }
    if ( [self.session canAddInput:audioDeviceInput] ) {
        [self.session addInput:audioDeviceInput];
    }
    else {
        NSLog( @"Could not add audio device input to the session" );
    }
    
    self.cameraPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.cameraPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.cameraPreviewLayer.frame = self.view.frame;
    self.cameraPreviewLayer.backgroundColor = [UIColor whiteColor].CGColor;
    [[self.cameraPreviewLayer connection] setAutomaticallyAdjustsVideoMirroring:YES];
    [self.view.layer addSublayer:self.cameraPreviewLayer];
    
    dispatch_async( self.sessionQueue, ^{
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        if ( [self.session canAddOutput:self.movieFileOutput] )
        {
            [self.session beginConfiguration];
            [self.session addOutput:self.movieFileOutput];
            self.session.sessionPreset = AVCaptureSessionPresetHigh;
            AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ( connection.isVideoStabilizationSupported ) {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            [self.session commitConfiguration];
            
            self.movieFileOutput = self.movieFileOutput;
            [self.session startRunning];
        }
    });
}

- (void)captureVideo {
    if (!self.movieFileOutput.isRecording) {
        [self.speechRecorder startRecordingSpeech];
    }
    dispatch_async( self.sessionQueue, ^{
        if (!self.movieFileOutput.isRecording) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
            });
            // Update the orientation on the movie file output video connection before starting recording.
            AVCaptureConnection *movieFileOutputConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            movieFileOutputConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            // Use HEVC codec if supported
            if ( [self.movieFileOutput.availableVideoCodecTypes containsObject:AVVideoCodecH264] ) {
                [self.movieFileOutput setOutputSettings:@{ AVVideoCodecKey : AVVideoCodecH264} forConnection:movieFileOutputConnection];
            }
            
            // Start recording to a temporary file.
            NSString *outputFileName = [NSUUID UUID].UUIDString;
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mp4"]];
            [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else {
            [self.movieFileOutput stopRecording];
            [self.speechRecorder stopRecordingSpeech];
            [self.recordingCompletionTimer invalidate];
        }
    } );
}

- (void)startCountdownTimer {
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimerLabel:) userInfo:nil repeats:YES];
    self.timerLabel.hidden = NO;
}

- (void)startRecordingCompletionTimer {
    self.recordingCompletionTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(stopRecordingVideo:) userInfo:nil repeats:NO];
    
}

- (void)updateTimerLabel:(NSTimer *)timer {
    NSInteger currentTime = [self.timerLabel.text integerValue];
    NSInteger updatedTime = currentTime = currentTime - 1;
    [self.timerLabel setText:[NSString stringWithFormat:@"%ld", updatedTime]];
}

- (void)stopRecordingVideo:(NSTimer *)timer {
    [self.speechRecorder stopRecordingSpeech];
    [self.movieFileOutput stopRecording];
    [self.recordingCompletionTimer invalidate];
}

#pragma mark - Video Recording Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    // Enable the Record button to let the user stop the recording.
    dispatch_async( dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{
            self.infoLabel.hidden = YES;
            self.captureVideoButton.selected = YES;
        }];
        [self startCountdownTimer];
        [self startRecordingCompletionTimer];
    });
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    
    if (!error) {
        [UIView animateWithDuration:0.2 animations:^{
            self.infoLabel.hidden = NO;
            self.timerLabel.hidden = YES;
            [self.infoLabel setText:kVAMUploadingMessage];
        }];
        
        [self.countdownTimer invalidate];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            //[self showSuccessAlert];
            [self.infoLabel setText:kVAMInfoMessage];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self postProcessVideo:outputFileURL];    
            });
            
        });
        
        //if ([[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path]) {
          //  [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:NULL];
        //}
        
        
    } else {
        NSLog( @"Movie file finishing error: %@", error );
    }
    
    
    dispatch_async( dispatch_get_main_queue(), ^{
        self.captureVideoButton.selected = NO;
        [self.timerLabel setText:@"10"];
    });
}

- (void)postProcessVideo:(NSURL *)videoURL {
    AVAsset *videoAsset = [AVURLAsset assetWithURL:videoURL];
    
    // 2 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    // 3 - Video track
    AVAssetTrack *assetVideoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].lastObject;
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                        ofTrack:assetVideoTrack
                         atTime:kCMTimeZero error:nil];
    
    if (assetVideoTrack && videoTrack) {
        [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    }
    
    // 4 - Subtitle track
    //AVURLAsset *subtitleAsset = [AVURLAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"subtitles" withExtension:@"vtt"]];
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask, YES);
    //NSString *documentsDirectory = [paths objectAtIndex:0];
    //NSString *path = [documentsDirectory stringByAppendingPathComponent:@"subtitles.vtt"];
    //NSLog(@"Load path : %@", path);
    AVURLAsset *subtitleAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:self.speechRecorder.subtitlesPath]];
    
    AVMutableCompositionTrack *subtitleTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeText
                                                                           preferredTrackID:kCMPersistentTrackID_Invalid];
    
    [subtitleTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                           ofTrack:[[subtitleAsset tracksWithMediaType:AVMediaTypeText] objectAtIndex:0]
                            atTime:kCMTimeZero error:nil];
    
    // 5 - Set up player
    self.player = [AVPlayer playerWithPlayerItem: [AVPlayerItem playerItemWithAsset:mixComposition]];
    [self.player addObserver:self forKeyPath:@"rate" options:0 context:0];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    [self.playerLayer setFrame:self.view.frame];
    [self.view.layer addSublayer:self.playerLayer];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error: nil];
    
    [self.player play];
}

- (void)stopped {
    [self.playerLayer removeFromSuperlayer];
    [self.player removeObserver:self forKeyPath:@"rate"]; //assumes we are the only observer
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == 0) {
        if(self.player.rate == 0.0) //stopped
            [self stopped];
    }
}

- (void)showSuccessAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Success"
                                                                             message:@"Video Auto Message successfully uploaded"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [alertController dismissViewControllerAnimated:YES completion:nil];
                                                      }]];
    [self presentViewController:alertController animated:YES completion:nil];
}


- (AVCaptureDevice *)frontCamera {
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    for (AVCaptureDevice *device in session.devices) {
        if ([device position] == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}


#pragma mark - Properties

- (UIButton *)captureVideoButton {
    return _captureVideoButton = _captureVideoButton ?: ({
        UIButton *button = [[UIButton alloc] initForAutoLayout];
        [button setTitle:@"" forState:UIControlStateNormal];
        [button setBackgroundImage:[UIImage imageNamed:@"takePhotoIcon"] forState:UIControlStateNormal];
        [button setBackgroundImage:[UIImage imageNamed:@"stop_recording"] forState:UIControlStateSelected];
        [button.layer setCornerRadius:68/2.f];
        [button addTarget:self action:@selector(captureVideo) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
}

- (UILabel *)infoLabel {
    return _infoLabel = _infoLabel ?: ({
        UILabel *infoLabel = [[UILabel alloc] initForAutoLayout];
        [infoLabel setText:kVAMInfoMessage];
        [infoLabel setFont:[UIFont systemFontOfSize:14.f weight:UIFontWeightMedium]];
        infoLabel.textColor = [UIColor whiteColor];
        infoLabel.textAlignment = NSTextAlignmentCenter;
        infoLabel.backgroundColor = [UIColor clearColor];
        infoLabel;
    });
}

- (UILabel *)timerLabel {
    return _timerLabel = _timerLabel ?: ({
        UILabel *timerLabel = [[UILabel alloc] initForAutoLayout];
        [timerLabel setText:@"10"];
        [timerLabel setFont:[UIFont systemFontOfSize:44.f weight:UIFontWeightMedium]];
        timerLabel.textColor = [UIColor whiteColor];
        timerLabel.textAlignment = NSTextAlignmentCenter;
        timerLabel.backgroundColor = [UIColor clearColor];
        timerLabel;
    });
}

@end
