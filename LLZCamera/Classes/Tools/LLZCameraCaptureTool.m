//
//  LLZCameraCaptureTool.m
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import "LLZCameraCaptureTool.h"
#import "LLZCameraCaptureFileCacheManager.h"
#import <CoreMotion/CoreMotion.h>
#import "UIViewController+Utils.h"
//@import LLZUIKit;

static const CGFloat kLLZCameraCaptureManager_TimerInterval = 0.02;  // 进度条timer 20ms回调一次
static const CGFloat kLLZCameraCaptureManager_MaxRecordTime = 30;    // 最大录制时间 30s

@interface LLZCameraCaptureTool()<AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

// 音视频捕获会话
@property (nonatomic, strong) AVCaptureSession *captureSession;
// 摄像头实时输出图层
@property(nonatomic, strong, readwrite) AVCaptureVideoPreviewLayer *captureLayer;

// 视频输入
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
// 音频输入
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

// 视频文件输出
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;

// 照片文件输出
@property (nonatomic, strong) AVCapturePhotoOutput *imageFileOutput;

// 输出照片配置
@property (nonatomic, strong) AVCapturePhotoSettings *captureSettings;

@property (nonatomic, assign) BOOL isRecording; //是否正在录制
@property (nonatomic, assign) UIDeviceOrientation shootingOrientation;   //拍摄录制时的手机方向
@property (nonatomic, strong) CMMotionManager *motionManager;       //运动传感器  监测设备方向



@property (nonatomic, strong) NSTimer *timer;
// 录制时间
@property (nonatomic, assign) CGFloat recordTime;

@property (nonatomic, copy) PhotoCapturedBlock photoCapturedBlock;

@property (nonatomic, copy) TorchModeChangedBlock torchModeChangedBlock;

@property (nonatomic, assign) BOOL allowRecordingVideo;

/// 摄像头方向 默认后置摄像头
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;
/// 是否开启自动闪光灯识别
@property (nonatomic, assign) BOOL isAutoLightOn;

// 相机手电筒模式
@property (nonatomic, assign, readwrite) AVCaptureTorchMode torchMode;


@property (nonatomic, assign) CGFloat minZoomFactor;
@property (nonatomic, assign) CGFloat maxZoomFactor;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@end

@implementation LLZCameraCaptureTool

+ (instancetype)captureToolForTakingPhotoWithCamera:(AVCaptureDevicePosition)devicePosition{
    LLZCameraCaptureTool *captureTool = [[LLZCameraCaptureTool alloc] init];
    captureTool.allowRecordingVideo = NO;
    captureTool.devicePosition = devicePosition;
    captureTool.flashMode = AVCaptureFlashModeOff;
    captureTool.torchMode = AVCaptureTorchModeOff;
    return captureTool;
}

+ (instancetype)captureToolForRecordingVideoWithCamera:(AVCaptureDevicePosition)devicePosition{
    LLZCameraCaptureTool *captureTool = [[LLZCameraCaptureTool alloc] init];
    captureTool.allowRecordingVideo = YES;
    captureTool.devicePosition = devicePosition;
    captureTool.flashMode = AVCaptureFlashModeOff;
    captureTool.torchMode = AVCaptureTorchModeOff;
    [captureTool configureAVAudioSessionInBackgroundMode];
    return captureTool;
}

#pragma mark - Life Cycle
- (void)dealloc {
    [_timer invalidate];
    _timer = nil;
    _recordTime = 0;
    _photoCapturedBlock = nil;
    [self stopRecordingVideo];
    [self stopRunning];
    [_captureLayer removeFromSuperlayer];
}

- (instancetype)init {
    self = [super init];
    if(self){
        // 清除之前的缓存文件夹
        [LLZCameraCaptureFileCacheManager cleanCacheFiles];
    }
    return self;
}

#pragma mark - 初始化配置

// 配置后台播放音频
- (void)configureAVAudioSessionInBackgroundMode {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil]; //支持播放，支持录制
    [session setMode:AVAudioSessionModeVideoRecording error:nil];
    [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)configureAVCaptureSession {
    [self.captureSession beginConfiguration];
    if(_allowRecordingVideo){
        // 配置视频采集质量
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
            [self.captureSession setSessionPreset:AVCaptureSessionPresetHigh];
        } else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
        } else {
            [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
        }
    } else {
        [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    
    // 添加输入
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    
    // 添加照片输出
    if ([self.captureSession canAddOutput:self.imageFileOutput]) {
        [self.captureSession addOutput:self.imageFileOutput];
    }
    
    if(self.allowRecordingVideo){
        // 添加音频输入
        if ([self.captureSession canAddInput:self.audioInput]) {
            [self.captureSession addInput:self.audioInput];
        }
        // 添加视频输出
        if ([self.captureSession canAddOutput:self.movieFileOutput]) {
            [self.captureSession addOutput:self.movieFileOutput];
        }
    }
    
    [self.captureSession commitConfiguration];
    
    // 配置 capture connection
    AVCaptureConnection * captureConnection = [self getCurrentCaptureConnection];
    [self configureCaptureConnection:captureConnection shouldResetConfiguration:YES];
}



- (void)startRunning {
    if(!self.captureSession.isRunning){
        [self.captureSession startRunning];
    }
    [self startUpdateDeviceDirection];
}

///结束捕获
- (void)stopRunning {
    if (self.captureSession.isRunning) {
        [self.captureSession stopRunning];
    }
    [self stopUpdateDeviceDirection];
}

- (BOOL)isRunning {
    return self.captureSession.isRunning;
}


#pragma mark - 聚焦 / 曝光设置

// 设置聚焦
- (void)setFocusWithPoint:(CGPoint)point {
    CGPoint cameraPoint = [self.captureLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeAutoExpose point:cameraPoint];
}

// 配置聚焦和曝光
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode point:(CGPoint)point {
    AVCaptureDevice *device = [self.videoInput device];
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        
        // 聚焦模式
        if ([device isFocusModeSupported:focusMode]) {
            [device setFocusMode:focusMode];
        }
        
        // 聚焦位置
        if ([device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:point];
        }
        
        // 曝光模式
        if ([device isExposureModeSupported:exposureMode]) {
            [device setExposureMode:exposureMode];
        }
        
        // 曝光位置
        if ([device isExposurePointOfInterestSupported]) {
            [device setExposurePointOfInterest:point];
        }
        [device unlockForConfiguration];
        if(error){
            NSLog(@"设置焦距/曝光失败，失败原因：%@", error.description);
        }
    }
}

#pragma mark - 摄像头

// 设置持续曝光模式
- (void)configureExposureModeWithDevice:(AVCaptureDevice *)device {
    NSError *error = nil;
    [device lockForConfiguration:&error];
    if (error) {
        NSLog(@"设置持续曝光失败%@", error.description);
    }
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    [device unlockForConfiguration];
}

// 切换摄像头
- (void)switchCamera {
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.videoInput];
    AVCaptureDevice *device = [self getSwitchCameraDevice];
    self.devicePosition = [device position];
    [self configureExposureModeWithDevice:device];
    
    NSError *error = nil;
    self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if(error){
        NSLog(@"切换摄像头失败，失败原因: %@", error.description);
    }
    
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    [self.captureSession commitConfiguration];
    
    // 切换 input 需要重新配置connection
    AVCaptureConnection * captureConnection = [self getCurrentCaptureConnection];
    [self configureCaptureConnection:captureConnection shouldResetConfiguration:YES];
}

// 获取当前希望切换的摄像头
- (AVCaptureDevice *)getSwitchCameraDevice {
    AVCaptureDevice *currentDevice = [self.videoInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    
    // 当前摄像头方向不确定 或者 是前置摄像头
    BOOL isUnspecifiedOrFront = (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront);
    
    // 希望切换的摄像头方向
    AVCaptureDevicePosition switchPostion = isUnspecifiedOrFront ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    
    
    AVCaptureDevice *switchDevice = [self cameraWithPosition:switchPostion];
    
    return switchDevice;
}



#pragma mark - 闪光灯

- (void)switchFlashMode {
    if(self.flashMode == AVCaptureFlashModeOn){
        self.flashMode = AVCaptureFlashModeOff;
    } else {
        self.flashMode = AVCaptureFlashModeOn;
    }
}

#pragma mark - 手电筒

- (void)switchTorchMode {
    AVCaptureDevice *device = [self.videoInput device];
    if([device hasTorch]) {
        [device lockForConfiguration:nil];
        if(_torchMode == AVCaptureTorchModeOff){
            _torchMode = AVCaptureTorchModeOn;
        } else {
            _torchMode = AVCaptureTorchModeOff;
        }
        [device setTorchMode:_torchMode];
        [device unlockForConfiguration];
    }
    else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法使用手电筒" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }];
        [alert addAction:cancelAction];
        UIViewController *vc = [UIViewController currentViewController];
        [vc presentViewController:alert animated:YES completion:nil];
    }
}

- (AVCaptureTorchMode)torchMode {
    AVCaptureDevice *device = [self.videoInput device];
//    if(![device hasTorch]) {
//        _torchMode = AVCaptureTorchModeOff;
//    }
    _torchMode = device.torchMode;
    
    return _torchMode;
}

#pragma mark - 自动光线识别

- (void)addAutoLightDetectionWithTorchModeChangedBlock:(TorchModeChangedBlock)block {
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    if ([self.captureSession canAddOutput:output]) {
        [self.captureSession addOutput:output];
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //关闭监听闪光灯
        weakSelf.isAutoLightOn =  YES;
    });
    if(block){
        self.torchModeChangedBlock = block;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_isAutoLightOn) {
        return;
    }
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    // brightnessValue 值代表光线强度，值越小代表光线越暗
    NSLog(@"当前识别光线强度: [%f]",brightnessValue);
    if (brightnessValue <= -3 && _torchMode == AVCaptureTorchModeOff) {
        _isAutoLightOn = YES;
        [self switchTorchMode];
        if(self.torchModeChangedBlock){
            self.torchModeChangedBlock();
            NSLog(@"当前识别光线强度: [%f]， 已自动开启手电筒",brightnessValue);
        }
    }
}

#pragma mark - 拍照

- (void)takePhotoWithCompletion:(PhotoCapturedBlock)completion{
    AVCaptureConnection *captureConnection = [self.imageFileOutput connectionWithMediaType:AVMediaTypeVideo];
    if(!captureConnection){
        NSLog(@"拍照失败!");
        return;
    }
    
    [self configureCaptureConnection:captureConnection shouldResetConfiguration:NO];
    
    self.photoCapturedBlock = completion;
    
    [_imageFileOutput capturePhotoWithSettings:self.captureSettings delegate:self];
}


#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error API_AVAILABLE(ios(10.0)){
    if(error){
        NSLog(@"an unexpected error occurs while an AVCaptureSession instance is running. code : %@ reason : %d", error.localizedDescription, (int)error.code);
    }
    NSURL *fileUrl;
    NSData *imageData = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
    NSString *filePath = [LLZCameraCaptureFileCacheManager writeToLocalCacheFilePathWithImageData:imageData];
    fileUrl = [NSURL fileURLWithPath:filePath];
    if(self.photoCapturedBlock){
        self.photoCapturedBlock(fileUrl);
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error API_AVAILABLE(ios(11.0)) {
    if(error){
        NSLog(@"an unexpected error occurs while an AVCaptureSession instance is running. code : %@ reason : %d", error.localizedDescription, (int)error.code);
    }
    NSURL *fileUrl;
    NSData *imageData = [photo  fileDataRepresentation];
    NSString *filePath = [LLZCameraCaptureFileCacheManager writeToLocalCacheFilePathWithImageData:imageData];
    fileUrl = [NSURL fileURLWithPath:filePath];
    if(self.photoCapturedBlock){
        self.photoCapturedBlock(fileUrl);
    }
}


#pragma mark - 录制

// 开始录制
- (void)startRecordingVideoToFileURL:(NSURL *)outputFile {
    self.isRecording = YES;
    AVCaptureConnection * captureConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (!captureConnection) return;
    if ([self.movieFileOutput isRecording]) return;
    
    [self configureCaptureConnection:captureConnection shouldResetConfiguration:NO];
    
    [self.movieFileOutput startRecordingToOutputFileURL:outputFile recordingDelegate:self];
}

// 停止录制
- (void)stopRecordingVideo {
    self.isRecording = NO;
    if (self.movieFileOutput.isRecording) {
        [self stopTimer];
        [self.movieFileOutput stopRecording];
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

// 录制开始
- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections {
    [self startTimer];
}

// 录制结束
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
    [self stopTimer];
    // error/warning问题代码修改，申明的变量未使用 modify by billows
//    NSData *data = [[NSFileManager defaultManager] contentsAtPath:outputFileURL.path];
//    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    if (self.delegate && [self.delegate respondsToSelector:@selector(captureTool:didFinishRecordingWithOutput:atURL:fromConnections:error:)]) {
        [self.delegate captureTool:self didFinishRecordingWithOutput:output atURL:outputFileURL fromConnections:connections error:error];
    }
}

#pragma mark - capture connection

- (AVCaptureConnection *)getCurrentCaptureConnection {
    
    AVCaptureConnection *captureConnection;
    if(_allowRecordingVideo){
        captureConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    }
    captureConnection = [self.imageFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    return captureConnection;
    
}


- (BOOL)configureCaptureConnection:(AVCaptureConnection *)captureConnection shouldResetConfiguration:(BOOL) shouldResetConfiguration {
    if (!captureConnection) {
        return NO;
    }
    
    
    if(shouldResetConfiguration){
        // 设置视频稳定模式 防抖
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        // 设置是否为镜像 (前置摄像头采集到的数据本来就是翻转的，这里设置为镜像把画面转回来)
        if (self.devicePosition == AVCaptureDevicePositionFront && captureConnection.supportsVideoMirroring) {
            captureConnection.videoMirrored = self.needAdjustVideoMirroring;
        }
        
        // 设置视频原始方向
        captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        
    } else {
        // 设置视频方向，改变原视频 / 图像输出方向
        if ([captureConnection isVideoOrientationSupported] && self.needFixPhotoOrientation){
            captureConnection.videoOrientation = [self outputOrientationWithDeviceOrientation:self.shootingOrientation];
        }
    }
    
    return YES;
}

- (AVCaptureVideoOrientation)outputOrientationWithDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    if(self.PhotoOutputOrientationBlock){
        return self.PhotoOutputOrientationBlock(deviceOrientation);
    }
    if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
        return AVCaptureVideoOrientationLandscapeLeft;
    } else if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
        return AVCaptureVideoOrientationLandscapeRight;
    } else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        return AVCaptureVideoOrientationPortraitUpsideDown;
    } else {
        return AVCaptureVideoOrientationPortrait;
    }
}


#pragma mark - 计时器

// 计时器定时回调方法
- (void)fireWithTimer:(NSTimer *)timer {
    self.recordTime += kLLZCameraCaptureManager_TimerInterval;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(captureTool:didFinishVideoRecordingOfCurrentTime:withTotalTime:)]) {
        [self.delegate captureTool:self didFinishVideoRecordingOfCurrentTime:self.recordTime withTotalTime:self.videoMaximumDuration];
    }
    
    self.recordTime >= self.videoMaximumDuration ? [self stopRecordingVideo] : nil;
}

// 开启计时器
- (void)startTimer {
    [self.timer invalidate];
    self.timer = nil;
    self.recordTime = 0;
    [self.timer fire];
}

// 停掉计时器
- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}


#pragma mark - Getter

- (dispatch_queue_t)sessionQueue {
    if(!_sessionQueue){
        _sessionQueue = dispatch_queue_create("com.camera.sessionqueue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}

- (AVCaptureVideoPreviewLayer *)captureLayer {
    if (!_captureLayer) {
        _captureLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        _captureLayer.masksToBounds = YES;
        _captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _captureLayer;
}

- (AVCaptureDeviceInput *)videoInput {
    if (!_videoInput) {
        __block AVCaptureDevice *device = [self cameraWithPosition: _devicePosition];
        [self configureExposureModeWithDevice:device];
        _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    }
    return _videoInput;
}

- (AVCaptureDeviceInput *)audioInput {
    if (!_audioInput) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        NSError *error = nil;
        _audioInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (error) {
            NSLog(@"get audio input error: %@", error.description);
        }
    }
    return _audioInput;
}

- (AVCaptureMovieFileOutput *)movieFileOutput {
    if (!_movieFileOutput) {
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
//        _movieFileOutput = [[AVCaptureVideoDataOutput alloc] init];
    }
    return _movieFileOutput;
}

- (AVCapturePhotoOutput *)imageFileOutput {
    if (!_imageFileOutput) {
        _imageFileOutput = [[AVCapturePhotoOutput alloc] init];
    }
    return _imageFileOutput;
}


- (CMMotionManager *)motionManager {
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

- (NSTimer *)timer {
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:kLLZCameraCaptureManager_TimerInterval target:self selector:@selector(fireWithTimer:) userInfo:nil repeats:YES];
    }
    return _timer;
}

- (CGFloat)videoMaximumDuration {
    if(!_videoMaximumDuration){
        _videoMaximumDuration =  kLLZCameraCaptureManager_MaxRecordTime;
    }
    return _videoMaximumDuration;
}

- (AVCapturePhotoSettings *)captureSettings {
    _captureSettings = [AVCapturePhotoSettings photoSettings];
    NSDictionary *setDic;
    if (@available(iOS 11.0, *)) {
        setDic = @{AVVideoCodecKey: AVVideoCodecTypeJPEG};
    } else {
        setDic = @{AVVideoCodecKey: AVVideoCodecJPEG};
    }
    _captureSettings = [AVCapturePhotoSettings photoSettingsWithFormat:setDic];
    AVCaptureDevice *device = [self.videoInput device];
    // 闪光灯配置
    if(_flashMode && [device hasFlash]){
        _captureSettings.flashMode = _flashMode;
    }
    return _captureSettings;
}

- (CGFloat)videoZoomFactor {
    return [self.videoInput device].videoZoomFactor;
}

- (void)setVideoZoomFactor:(CGFloat)videoZoomFactor {
    NSError *error = nil;
    if (videoZoomFactor <= self.maxZoomFactor &&
        videoZoomFactor >= self.minZoomFactor){
        if ([[self.videoInput device] lockForConfiguration:&error] ) {
            [self.videoInput device].videoZoomFactor = videoZoomFactor;
            [[self.videoInput device] unlockForConfiguration];
        } else {
            NSLog( @"调节焦距失败: %@", error );
        }
    }
}

//最小缩放值 焦距
- (CGFloat)minZoomFactor {
    CGFloat minZoomFactor = 1.0;
    if (@available(iOS 11.0, *)) {
        minZoomFactor = [self.videoInput device].minAvailableVideoZoomFactor;
    }
    return minZoomFactor;
}
//最大缩放值 焦距
- (CGFloat)maxZoomFactor {
    CGFloat maxZoomFactor = [self.videoInput device].activeFormat.videoMaxZoomFactor;
    if (@available(iOS 11.0, *)) {
        maxZoomFactor = [self.videoInput device].maxAvailableVideoZoomFactor;
    }
    if (maxZoomFactor > 6) {
        maxZoomFactor = 6.0;
    }
    return maxZoomFactor;
}


#pragma mark - 重力感应监测设备方向
///开始监听设备方向
- (void)startUpdateDeviceDirection {
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        //回调会一直调用,建议获取到就调用下面的停止方法，需要再重新开始，当然如果需求是实时不间断的话可以等离开页面之后再stop
        [self.motionManager setAccelerometerUpdateInterval:1.0];
        __weak typeof(self) weakSelf = self;
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            double x = accelerometerData.acceleration.x;
            double y = accelerometerData.acceleration.y;
            if ((fabs(y) + 0.1f) >= fabs(x)) {
                if (y >= 0.1f) {
                    if (weakSelf.shootingOrientation == UIDeviceOrientationPortraitUpsideDown) {
                        return ;
                    }
                    weakSelf.shootingOrientation = UIDeviceOrientationPortraitUpsideDown;
                    NSLog(@"监测到设备方向变化 -> down");
                } else {
                    if (weakSelf.shootingOrientation == UIDeviceOrientationPortrait) {
                        return ;
                    }
                    weakSelf.shootingOrientation = UIDeviceOrientationPortrait;
                    NSLog(@"监测到设备方向变化 -> portrait");
                }
            } else {
                if (x >= 0.1f) {
                    if (weakSelf.shootingOrientation == UIDeviceOrientationLandscapeRight) {
                        return ;
                    }
                    weakSelf.shootingOrientation = UIDeviceOrientationLandscapeRight;
                    NSLog(@"监测到设备方向变化 -> right");
                } else if (x <= 0.1f) {
                    if (weakSelf.shootingOrientation == UIDeviceOrientationLandscapeLeft) {
                        return ;
                    }
                    weakSelf.shootingOrientation = UIDeviceOrientationLandscapeLeft;
                    NSLog(@"监测到设备方向变化 -> left");
                } else  {
                    if (weakSelf.shootingOrientation == UIDeviceOrientationPortrait) {
                        return ;
                    }
                    weakSelf.shootingOrientation = UIDeviceOrientationPortrait;
                    NSLog(@"监测到设备方向变化 -> portrait");
                }
            }
            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(captureTool:deviceOrientationDidChange:)]){
                [weakSelf.delegate captureTool:weakSelf deviceOrientationDidChange:weakSelf.shootingOrientation];
            }
        }];
    }
}
/// 停止监测方向
- (void)stopUpdateDeviceDirection {
    if ([self.motionManager isAccelerometerActive] == YES) {
        [self.motionManager stopAccelerometerUpdates];
        _motionManager = nil;
    }
}



#pragma mark - helpers
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    NSArray *devices = deviceDiscoverySession.devices;
    __block AVCaptureDevice *targetCamera;
    [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *camera, NSUInteger idx, BOOL * _Nonnull stop) {
        if (camera.position == position) {
            targetCamera = camera;
            *stop = YES;
        }
    }];
    return targetCamera;
}


@end
