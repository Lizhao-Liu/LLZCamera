//
//  LLZCustomBaseCameraViewController.m
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import "LLZBaseCameraViewController.h"
#import "LLZCameraCaptureTool.h"
#import "LLZCameraControlsModel.h"
#import "LLZCameraCaptureFileCacheManager.h"
#import "LLZCameraRecordProgressView.h"
#import "LLZCameraPlayerView.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <ImageIO/ImageIO.h>
#import "UIViewController+Utils.h"

#define SCREEN_WIDTH  [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define kHeightOfBottomViewForDefaultCamera 96

@interface LLZBaseCameraViewController ()<LLZCameraCaptureToolDelegate, UIGestureRecognizerDelegate, LLZCameraPlayerViewDelegate>

// 录制输出文件 临时本地路径URL
@property (nonatomic, strong) NSURL *recordVideoUrl;
// 录制输出文件 压缩完成后的本地路径URL
@property (nonatomic, strong) NSURL *recordVideoOutPutUrl;
// 录制时长
@property (nonatomic, assign) NSUInteger recordDuration;

// 是否处于循环播放中
@property (nonatomic, assign, getter=isInLoopPlay) BOOL inLoopPlay;

// 父容器view
@property (nonatomic, strong) UIView *containerView;

// 录制按钮
@property (nonatomic, strong) UIView *captureBtn;

// 录制按钮下面的背景view
@property (nonatomic, strong) UIView *captureBtnBGView;

// 返回按钮
@property (nonatomic, strong) UIButton *dismissButton;

// 提示标签
@property (nonatomic, strong) UILabel *tipLabel;

// 聚焦控件
@property (nonatomic, strong) UIImageView *focusImageView;

// 长按录制进度view
@property (nonatomic, strong) LLZCameraRecordProgressView *progressView;

//当前焦距比例系数
@property (nonatomic, assign) CGFloat currentZoomFactor;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property (nonatomic, strong) dispatch_group_t cameraConfigGroup;

@property (nonatomic, assign) BOOL isShownBefore;

@property (nonatomic, assign) BOOL isUIInitialized;

@end

@implementation LLZBaseCameraViewController

#pragma mark - life cycle

- (instancetype)init{
    self = [super init];
    if(self){
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        _needAdjustVideoMirroring = YES;
        _needFixPhotoOrientation = NO;
        _autoCloseOnCapture = YES;
    }
    return self;
}

- (instancetype)initCustomCameraWithControlOptions:(LLZCameraControlsModel *)controlOptions allowRecording:(BOOL)allowRecording {
    self = [super init];
    if(self){
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        _needAdjustVideoMirroring = YES;
        _needFixPhotoOrientation = NO;
        _cameraMode = LLZBaseCameraModeCustom;
        _controlOptions = controlOptions;
        _allowRecording = allowRecording;
        _autoCloseOnCapture = YES;
        _videoMinimumDuration = 5;
        _videoMaximumDuration = 30;
    }
    return self;
}

- (instancetype)initDefaultCameraWithControlOptions:(LLZCameraControlsModel *)controlOptions{
    self = [super init];
    if(self){
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        _needAdjustVideoMirroring = YES;
        _needFixPhotoOrientation = NO;
        _cameraMode = LLZBaseCameraModeDefault;
        _controlOptions = controlOptions;
        _allowRecording = NO;
        _autoCloseOnCapture = YES;
    }
    return self;
}

- (dispatch_queue_t)sessionQueue {
    if(!_sessionQueue){
        _sessionQueue = dispatch_queue_create("com.camera.sessionqueue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

- (dispatch_group_t)cameraConfigGroup {
    if(!_cameraConfigGroup){
        _cameraConfigGroup = dispatch_group_create();
    }
    return _cameraConfigGroup;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // capture tool 初始化
    [self setUpCaptureTool];
    
    // 监听 AVCaptureSession 运行时错误通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
    
    dispatch_group_enter(self.cameraConfigGroup);
    dispatch_async(self.sessionQueue, ^{
        [self.captureTool configureAVCaptureSession];
        dispatch_group_leave(self.cameraConfigGroup);
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    /**
     当从下一级页面返回时，需要更新相机控件的状态
     */
    if(_isShownBefore){
        [self updateUI];
//        [self restartCamera];
//        return;
    }
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    if(!_isUIInitialized){
        /**
         在这个时机更新UI，确保相机控件在安全区域内展示
         */
        [self initializeUI];
    }
}

- (void)initializeUI {
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.captureView];
    [self setUpMaskView]; // 添加蒙版视图
    /**
     涉及到 captureTool 相关的 UI 视图， 需要确保 capture tool 配置相机的操作已经完成
     */
    dispatch_group_notify(self.cameraConfigGroup, dispatch_get_main_queue(), ^{
        [self setUpControls]; // 添加相机控件
        [self.captureView.layer insertSublayer:self.captureTool.captureLayer atIndex:0]; // 添加相机捕获layer 至最上层
        self.captureTool.captureLayer.frame = self.captureView.frame;
    });
    self.isUIInitialized = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /**
     官方 demo 将 startRunning 放在 viewWillAppear 时机
     这里 startRunning 放在 viewDidAppear 是因为放在 viewWillAppear 有一些老的机型或者系统版本出现了很长时间的卡顿黑屏，测试下来放在 viewDidAppear 可以解决这个长时间的黑屏问题
     但理论上 viewDidAppear 会导致相机视图流启动时机较慢，目前没有更好的办法
     */
    dispatch_async(self.sessionQueue, ^{
        [self.captureTool startRunning];
        [self viewAppearRetryStartRunning];
    });
    _isShowingCamera = YES;
    _isShownBefore = YES;
    NSLog(@"自定义相机已弹起，相机模式:%ld  支持录像:%d  最长录制时长:%f  手电筒:%d  闪光灯:%d  翻转镜头:%d  自动光线检测:%d  显示预览:%d  输出图片长宽最大像素:%f, 自动保存:%d  拍摄完成自动关闭相机:%d", (long)_cameraMode, _allowRecording, _videoMaximumDuration, _controlOptions.needTorchSwitch, _controlOptions.needFlashSwitch, _controlOptions.needCameraSwitch, _controlOptions.needAutoLightDetection, _needPreview, _cameraMaxPixelSize, _needSaveToAlbum, _autoCloseOnCapture);
}

- (void)viewAppearRetryStartRunning {
    NSLog(@"自定义相机启动图像流");
    // 0.1s 后补偿一次启动
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = self;
        if (strongSelf.dismissButton.hidden == NO && strongSelf.captureTool.isRunning == NO) {
            NSLog(@"自定义相机启动图像流，0.1s后的重试");
            dispatch_async(weakSelf.sessionQueue, ^{
                [strongSelf.captureTool startRunning];
            });
        }
    });
}

- (void)viewWillDisappear:(BOOL)animated{
    [_captureTool stopRunning];
    _isShowingCamera = NO;
}

- (void)dealloc {
    _captureTool.delegate = nil;
    _captureTool = nil;
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"自定义相机已释放");
}

// 处理 AVCaptureSession 运行时错误
- (void)handleSessionRuntimeError:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    if (error) {
        /**
         原因汇总：
         https://www.jianshu.com/p/e5e6dc8abf88
         */
        NSLog(@"an unexpected error occurs while an AVCaptureSession instance is running. code : %@ reason : %d", error.localizedDescription, (int)error.code);
    }
}

#pragma mark - gesture methods

// 接受tap手势 - 拍照
- (void)didClickCaptureButton {
    NSLog(@"用户点击了拍摄");
    self.captureBtn.userInteractionEnabled = NO;
    // 1、重置数据
    self.recordVideoUrl = nil;
    self.recordVideoOutPutUrl = nil;
    // 2、隐藏无关控件
    self.dismissButton.hidden = YES;
    self.tipLabel.hidden = YES;
    if(_switchCameraButton){
        _switchCameraButton.hidden = YES;
    }
    if(_toggleFlashButton){
        _toggleFlashButton.hidden = YES;
    }
    if(_toggleTorchButton){
        _toggleTorchButton.hidden = YES;
    }
    // 3、开始拍照
    __weak __typeof(self)weakSelf = self;
    [self.captureTool takePhotoWithCompletion:^(NSURL * _Nonnull fileURL) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf.captureTool stopRunning];
         if(strongSelf.needPreview){
            // 预览图片
            if (fileURL != nil) {
                [strongSelf showVideoOrPhotoAtOutputUrl:fileURL];
            }
        } else {
            [strongSelf handleResultImageAtUrl:fileURL];
            if(strongSelf.autoCloseOnCapture){
                [strongSelf dismiss];
            } else {
                // 这里设置延迟操作是为了防止后续通过pushvc切换到其他vc出现的黑屏闪烁
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if(strongSelf.isShowingCamera){
                        [strongSelf restartCamera];
                    }
                });  
            }
        }
    }];
}

// 接收长按录制手势 - 录像
- (void)didReceiveRecordGestureRecognizer:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        
        // 1、重置数据
        self.recordVideoUrl = nil;
        self.recordVideoOutPutUrl = nil;
        
        // 2、展示按钮动画
        [self showStartRecordAnimation];
        
        // 3、修改长按背景控件frame
        CGRect rect = self.progressView.frame;
        rect.size = CGSizeMake(self.captureBtnBGView.frame.size.width-3, self.captureBtnBGView.frame.size.height-3);
        rect.origin = CGPointMake(self.captureBtnBGView.frame.origin.x+1.5, self.captureBtnBGView.frame.origin.y+1.5);
        self.progressView.frame = self.captureBtnBGView.frame;
        
        // 4、隐藏无关控件
        self.dismissButton.hidden = YES;
        self.tipLabel.hidden = YES;
        if(_switchCameraButton){
            _switchCameraButton.hidden = YES;
        }
        if(_toggleFlashButton){
            _toggleFlashButton.hidden = YES;
        }
        if(_toggleTorchButton){
            _toggleTorchButton.hidden = YES;
        }
        
        // 5、开始录制
        NSURL *url = [NSURL fileURLWithPath:[LLZCameraCaptureFileCacheManager cacheFilePath:YES]];
        [self.captureTool startRecordingVideoToFileURL:url];
        NSLog(@"自定义相机录像开始");
        
    } else if (gesture.state >= UIGestureRecognizerStateEnded ||
               gesture.state >= UIGestureRecognizerStateCancelled ||
               gesture.state >= UIGestureRecognizerStateFailed) {
        
        [self.captureTool stopRecordingVideo];
        NSLog(@"自定义相机录像结束");
    }
}



// 关闭照相机
- (void)didClickDismissButton {
    [self dismiss];
    if(self.delegate && [self.delegate respondsToSelector:@selector(didClickCancelWithLLZCameraViewController:)]){
        [self.delegate didClickCancelWithLLZCameraViewController:self];
    }
    NSLog(@"相机已关闭");
}

// 切换闪光灯
- (void)didClickSwitchFlashModeButton {
    [self.captureTool switchFlashMode];
    [self updateFlashBtnIcon];
    NSLog(@"相机闪光灯已%@", self.captureTool.flashMode ? @"开启": @"关闭");
}

// 切换手电筒
- (void)didClickSwitchTorchModeButton {
    [self.captureTool switchTorchMode];
    [self updateTorchBtnIcon];
    NSLog(@"相机手电筒已%@", self.captureTool.torchMode ? @"开启": @"关闭");
}

// 切换摄像头
- (void)didClickSwitchCameraButton {
    dispatch_group_enter(self.cameraConfigGroup);
    dispatch_async(self.sessionQueue, ^{
        [self.captureTool switchCamera];
        dispatch_group_leave(self.cameraConfigGroup);
    });
    dispatch_group_notify(self.cameraConfigGroup, dispatch_get_main_queue(), ^{
        [self updateTorchBtnIcon];
        [self updateFlashBtnIcon];
        NSLog(@"相机已翻转，当前使用%@摄像头", self.captureTool.devicePosition==AVCaptureDevicePositionFront ? @"前置": @"后置");
    });
}

#pragma mark - Capture Tool

- (void)setUpCaptureTool {
    // 初始摄像头
    AVCaptureDevicePosition camera;
    if(self.controlOptions.startWithFrontCamera){
        camera = AVCaptureDevicePositionFront;
    } else {
        camera = AVCaptureDevicePositionBack;
    }
    
    // 是否支持短视频录像
    if(_cameraMode == LLZBaseCameraModeCustom && _allowRecording){
        _captureTool = [LLZCameraCaptureTool captureToolForRecordingVideoWithCamera:camera];
    } else {
        _captureTool = [LLZCameraCaptureTool captureToolForTakingPhotoWithCamera:camera];
    }
    
    // 输出图像/视频配置
    if(_needAdjustVideoMirroring){
        _captureTool.needAdjustVideoMirroring = YES;
    }
    if(_needFixPhotoOrientation){
        _captureTool.needFixPhotoOrientation = YES;
    }
    if(_PhotoOutputOrientationBlock){
        _captureTool.PhotoOutputOrientationBlock = _PhotoOutputOrientationBlock;
    }
    if(_videoMaximumDuration){
        _captureTool.videoMaximumDuration = _videoMaximumDuration;
    }
    _captureTool.delegate = self;
}

#pragma mark - LLZCameraCaptureToolDelegate

// 进度条
- (void)captureTool:(LLZCameraCaptureTool *)captureTool didFinishVideoRecordingOfCurrentTime:(CGFloat)recordTime withTotalTime:(CGFloat)totalTime{
    self.progressView.total = totalTime;
    self.progressView.progress = recordTime;
//    LLZCameraLog_Info(@"正在录制视频... 进度时长: %f 总时长限制: %f", recordTime, totalTime);
}

// 录像结束回调
- (void)captureTool:(LLZCameraCaptureTool *)captureTool didFinishRecordingWithOutput:(AVCaptureFileOutput *)captureOutput atURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    [self.progressView setProgress:0];
    [self.captureTool stopRunning];
    if (!error) {
        
        // 赋值视频临时路径
        self.recordVideoUrl = outputFileURL;
        
        // 获取视频时长
        self.recordDuration = [LLZCameraCaptureFileCacheManager getVideoTotalDurationSecondsWithUrl:outputFileURL];
        
        // 最短录制时长限制
        if (self.recordDuration < self.videoMinimumDuration) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                UIImage *image = [strongSelf bundleWithImageName:@"camera_capture_failure"];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"录制时间太短" preferredStyle:(UIAlertControllerStyleAlert)];
                UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleCancel) handler:nil];
                [alertController addAction:action];
                [[UIViewController currentViewController] presentViewController:alertController animated:YES completion:nil];
                [self cancelPlayerView];
                NSLog(@"录制视频时间太短");
            });
            return;
        }
        
        // 自动播放
        if(self.needPreview){
            __weak __typeof(self)weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    [strongSelf showVideoOrPhotoAtOutputUrl:strongSelf.recordVideoUrl];
                }
            });
        } else {
            [self handleResultVideo];
            if(self.autoCloseOnCapture){
                [self dismiss];
            } else {
                // 这里设置延迟操作是为了防止后续通过pushvc切换到其他vc出现的黑屏闪烁
                __weak __typeof(self)weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if(self.isShowingCamera){
                        [self restartCamera];
                    }
                });
            }
        }
        
    }
}

- (void)captureTool:(LLZCameraCaptureTool *)captureTool deviceOrientationDidChange:(UIDeviceOrientation)orientation {
    [self deviceOrientationDidChange:orientation];
}

#pragma mark - UI

- (void)setUpControls {
    if(self.controlOptions.needAutoLightDetection){
        __weak __typeof(self) weakSelf = self;
        [self.captureTool addAutoLightDetectionWithTorchModeChangedBlock:^{
            [weakSelf updateTorchBtnIcon];
        }];
    }
    switch (_cameraMode) {
        case LLZBaseCameraModeDefault: {
            CGRect rect = CGRectMake(0, CGRectGetMaxY(self.captureView.frame) , self.view.frame.size.width, kHeightOfBottomViewForDefaultCamera);
            _controlsView = [[UIView alloc] initWithFrame:rect];
            _controlsView.backgroundColor = [UIColor blackColor];

            [_controlsView addSubview:self.captureBtn];
            [_controlsView addSubview:self.dismissButton];

            CGFloat startMaxX = CGRectGetWidth(_controlsView.frame);
            if(self.controlOptions.needCameraSwitch){
                self.switchCameraButton.frame = CGRectMake(startMaxX-20-30, (CGRectGetHeight(_controlsView.frame)-30)/2, 30, 30);
                [_controlsView addSubview:self.switchCameraButton];
                startMaxX = CGRectGetMinX(self.switchCameraButton.frame);
            }
            
            if(self.controlOptions.needTorchSwitch){
                self.toggleTorchButton.frame = CGRectMake(startMaxX-25-30, (CGRectGetHeight(_controlsView.frame)-30)/2, 30, 30);
                [_controlsView addSubview:self.toggleTorchButton];
                startMaxX = CGRectGetMinX(self.toggleTorchButton.frame);
            }
            
            if(self.controlOptions.needFlashSwitch){
                self.toggleFlashButton.frame = CGRectMake(startMaxX-25-30, (CGRectGetHeight(_controlsView.frame)-30)/2, 30, 30);
                [_controlsView addSubview:self.toggleFlashButton];
                startMaxX = CGRectGetMinX(self.toggleFlashButton.frame);
            }
            [self.containerView addSubview:_controlsView];
            break;
        }
        case LLZBaseCameraModeCustom:{
            // 全屏相机，控件添加到捕获视图上
            _controlsView = self.captureView;
            [_controlsView addSubview:self.captureBtnBGView];
            [_controlsView addSubview:self.progressView];
            [_controlsView addSubview:self.captureBtn];
            [_controlsView addSubview:self.tipLabel];
            [_controlsView addSubview:self.dismissButton];
            [_controlsView bringSubviewToFront:self.captureBtn];
            _controlsView.userInteractionEnabled = YES;
            CGFloat startX = _controlsView.frame.size.width - 20 - 28;
            CGFloat startY = 10;
            if (@available(iOS 11.0, *)) {
                startY = startY + self.view.safeAreaInsets.top;
            }
            if(self.controlOptions.needCameraSwitch){
                self.switchCameraButton.frame = CGRectMake(startX, startY, 30, 28);
                [_controlsView addSubview:self.switchCameraButton];
                startY = startY + 60;
            }
            if(self.controlOptions.needTorchSwitch){
                self.toggleTorchButton.frame = CGRectMake(startX, startY, 30, 28);
                [_controlsView addSubview:self.toggleTorchButton];
                startY = startY + 60;
            }
            if(self.controlOptions.needFlashSwitch){
                self.toggleFlashButton.frame = CGRectMake(startX, startY, 30, 28);
                [_controlsView addSubview:self.toggleFlashButton];
                startY = startY + 60;
            }
            break;
        }
    }
}

- (void)deviceOrientationDidChange:(UIDeviceOrientation)orientation {
    // 根据方向旋转图片
    CGAffineTransform transform = CGAffineTransformMakeRotation([self rotationAngleForDeviceOrientation:orientation]);

    if(self.controlOptions.needCameraSwitch){
        self.switchCameraButton.imageView.transform = transform;
    }
    
    if(self.controlOptions.needTorchSwitch){
        self.toggleTorchButton.imageView.transform = transform;
    }
    
    if(self.controlOptions.needFlashSwitch){
       self.toggleFlashButton.imageView.transform = transform;
    }
    
    if((self.cameraMode == LLZBaseCameraModeDefault) && [self.captureBtn isKindOfClass:[UIButton class]]){
        UIButton *captureBtn = (UIButton *)self.captureBtn;
        captureBtn.imageView.transform = transform;
    }
}

- (CGFloat)rotationAngleForDeviceOrientation:(UIDeviceOrientation)orientation {
    CGFloat radians = 0.0;

    switch (orientation) {
        case UIDeviceOrientationPortrait:
            radians = 0.0;
            break;
        case UIDeviceOrientationLandscapeLeft:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeRight:
            radians = -M_PI_2;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            radians = M_PI;
            break;
        default:
            break;
    }
    return radians;
}


- (void)setUpMaskView {
    UIView *mask = [self setMaskViewWithFrame:self.captureView.bounds withTipString:self.cameraMaskTipString];
    if(mask){
        _cameraMaskView = mask;
    }
    if(self.cameraMaskView){
        self.cameraMaskView.frame = self.captureView.bounds;
        [self.captureView addSubview:self.cameraMaskView];
        NSLog(@"已添加相机自定义蒙版视图");
    }
}

// 蒙版， 子类可重写添加
- (UIView *)setMaskViewWithFrame:(CGRect)frame withTipString:(NSString *)tipString {
    return nil;
}

// 开始录制按钮动画
- (void)showStartRecordAnimation {
    [UIView animateWithDuration:0.2 animations:^{
        self.captureBtn.transform = CGAffineTransformMakeScale(0.66, 0.66);
        self.captureBtnBGView.transform = CGAffineTransformMakeScale(6.5/5, 6.5/5);
    }];
}

- (void)updateTorchBtnIcon {
    UIImage *icon = self.captureTool.torchMode ? [self bundleWithImageName:@"icon_light_on"] : [self bundleWithImageName:@"icon_light_off"];
    [_toggleTorchButton setImage:icon forState:UIControlStateNormal];
}

- (void)updateFlashBtnIcon {
    UIImage *icon = self.captureTool.flashMode ? [self bundleWithImageName:@"camera_flash_on"] : [self bundleWithImageName:@"camera_flash_off"];
    [_toggleFlashButton setImage:icon forState:UIControlStateNormal];
}

#pragma mark - 预览

// 重复播放录制好的视频 OR  预览展示拍照的图片
- (void)showVideoOrPhotoAtOutputUrl:(NSURL *)url {
    NSLog(@"自定义相机预览视图弹起");
    self.inLoopPlay = YES;
    LLZCameraPlayerView *playerView = [[LLZCameraPlayerView alloc] initWithFrame: self.containerView.frame url:url fileType: [LLZCameraCaptureFileCacheManager getFileTypeWithFileURL:url] needAutoFitImageSize:self.needFixPhotoOrientation];
    playerView.delegate = self;
    [self.containerView addSubview:playerView];
}

#pragma mark - LLZCameraPlayerViewDelegate

- (void)didClickCancelWithLLZCameraPlayerView:(nonnull LLZCameraPlayerView *)view fileURL:(nonnull NSURL *)fileURL fileType:(LLZCameraOutputFileType)fileType {
    self.inLoopPlay = NO;
    [self cancelPlayerView];
    NSLog(@"自定义相机预览视图关闭");
}

- (void)didClickConfirmWithLLZCameraPlayerView:(nonnull LLZCameraPlayerView *)view fileURL:(nonnull NSURL *)fileURL fileType:(LLZCameraOutputFileType)fileType {
    self.inLoopPlay = NO;
    if (fileType == LLZCameraCaptureFileType_Video) {
        [self handleResultVideo];
    } else if (fileType == LLZCameraCaptureFileType_Image) {
        [self handleResultImageAtUrl:fileURL];
    }
    if(self.autoCloseOnCapture){
        [self dismiss];
    } else {
        [self restartCamera];
    }
    NSLog(@"自定义相机预览视图关闭");
}


#pragma mark - 结果处理

- (void)handleResultVideo {
    __weak __typeof(self)weakSelf = self;
    [LLZCameraCaptureFileCacheManager compressVideoWithFileURL:self.recordVideoUrl complete:^(BOOL success, NSURL *url) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (success && url) {
            strongSelf.recordVideoOutPutUrl = url;
            [strongSelf callBackAvaliableVideoDelegate];
            if(self.needSaveToAlbum){
                [self saveVideoAtPath:url];
            }
            NSLog(@"录制完成，获取录制视频文件所在缓存地址: %@, 录制时长: %ld", self.recordVideoOutPutUrl, self.recordDuration);
        } else {
            [strongSelf showCompressFailedAlert];
        }
    }];
}

- (void)handleResultImageAtUrl:(nonnull NSURL *)fileURL {
    // 1. 重新调整捕获图片尺寸
    NSDictionary *result = [self preprocessImageAtUrl:fileURL];
    if(!result){ return; }
    UIImage *image = result[@"image"];
    NSData *data = result[@"data"];

    // 2. 最终结果图片回调给代理
    [self callBackAvaliablePhotoImageDelegateWithImageData:data withImage:image];
    
    // 3. 最终结果图片保存到相册
    if(self.needSaveToAlbum){
        [self saveImagePhotoAlbumWithImage:image];
    }
    NSLog(@"拍摄完成，获取拍摄图片数据: %@", data);
}


- (NSDictionary *)preprocessImageAtUrl:(nonnull NSURL *)fileURL {
    return [self resizedImageAtUrl:fileURL];
}

- (NSDictionary *)originalImageAtUrl:(nonnull NSURL *)fileURL {
    NSData *imageData = [[NSFileManager defaultManager] contentsAtPath:fileURL.relativePath];
    return @{@"image": [UIImage imageWithData:imageData], @"data": imageData};
}

- (NSDictionary *)resizedImageAtUrl:(nonnull NSURL *)fileURL{
    /**
     此处重置图片尺寸，使用 ImageIO 的接口，避免调用 UIImage 的 drawInRect: 方法执行带来的中间 bitmap 的产生。
     可以在不产生Dirty Memory的情况下，直接读取图像大小和元数据信息，不会带来额外的内存开销。
     其内存消耗即为目标尺寸需要的内存。(经过试验，指定尺寸1092情况下，此处内存消耗增量大约8.5M)
     */
    
    NSData *imageData = [[NSFileManager defaultManager] contentsAtPath:fileURL.relativePath];
    // 创建图像源
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (imageSource == NULL) {
        // 处理图像源创建失败的情况
        NSLog(@"图像源创建失败");
        return nil;
    }
    // 设置参数
    NSDictionary *options = @{
        (__bridge id)kCGImageSourceShouldCache: @NO, // 避免缓存整个图像到内存中
        (__bridge id)kCGImageSourceShouldAllowFloat: @YES, // 允许浮点数表示图像大小
        (__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(_cameraMaxPixelSize), // 指定缩略图的最大尺寸
        (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
        (__bridge id)kCGImageSourceCreateThumbnailWithTransform:@YES // 缩略图保留原图方向
    };
    
    // 使用缩略图生成目标图像
    CGImageRef thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
    UIImage *resizedImage = [UIImage imageWithCGImage:thumbnailImage];
    
    // 生成目标图像数据
    NSMutableData *resizedImageData = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)resizedImageData,
                                                                              kUTTypeJPEG,
                                                                              1,
                                                                              (__bridge CFDictionaryRef)@{
        (__bridge NSString *)kCGImageSourceShouldCache : @NO, // 避免缓存整个图像到内存中
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @NO
    });
    CGImageDestinationAddImage(imageDestination, thumbnailImage, NULL);
    CGImageDestinationFinalize(imageDestination);

    // 释放资源
    CFRelease(imageSource); // imageSource也可以不用手动释放，oc自动管理
    CGImageRelease(thumbnailImage); //使用CGImageRelease，即使thumbnailImage为空，也不会崩溃
    if(!imageDestination){ // 增加判空逻辑，避免imageDestination因某些未知错误返回null的情况
        NSLog(@"未知原因造成imageDestination为空");
    } else {
        CFRelease(imageDestination);
    }

    NSLog(@"自定义相机捕获图片尺寸已调整为: 宽度=%f 长度=%f", resizedImage.size.width, resizedImage.size.height);
    // 返回结果
    return @{@"image": resizedImage, @"data": resizedImageData};
}

- (void)callBackAvaliableVideoDelegate {
    UIImage *image = [LLZCameraCaptureFileCacheManager getThumbnailImageWithFilePath:self.recordVideoOutPutUrl time:0];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(didCaptureVideoWithLLZCameraViewController:fileURL:duration:thumbnailImage:)]) {
            [self.delegate didCaptureVideoWithLLZCameraViewController:self
                                                             fileURL:self.recordVideoOutPutUrl
                                                            duration:(int)self.recordDuration
                                                      thumbnailImage:image];
        }
    });
    
    
}

- (void)callBackAvaliablePhotoImageDelegateWithImageData: (NSData *)imageData withImage:(nonnull UIImage *)image {
    if (imageData == nil) { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(didCapturePhotoWithLLZCameraViewController:originalPhotoData:image:)]) {
            [self.delegate didCapturePhotoWithLLZCameraViewController:self originalPhotoData:imageData image:image];
        }
    });
}

#pragma mark - 图片/视频保存到相册

// 保存视频到相册
- (void)saveVideoAtPath: (NSURL *)fileUrl {
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
        UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
}

// 保存图片到相册
- (void)saveImagePhotoAlbumWithImage:(UIImage *)image {
    if (image == nil) { return; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    });
}

// 保存视频到相册回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if(error){
        NSLog(@"录制视频保存到相册失败，失败原因：%@", error.localizedDescription);
    } else {
        NSLog(@"录制视频保存到相册成功");
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    if(error){
        NSLog(@"保存相机捕获图片到相册失败，失败原因：%@", error.localizedDescription);
    } else {
        NSLog(@"保存相机捕获图片到相册成功");
    }
}


#pragma mark - 聚焦手势

// 添加聚焦手势
- (void)addFocusGestureRecognizer {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didReceiveFocusGestureRecognizer:)];
    tapGesture.delegate = self;
    [self.captureView addGestureRecognizer:tapGesture];
}

// 接收聚焦手势
- (void)didReceiveFocusGestureRecognizer:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.captureView];
    NSLog(@"自定义相机已接收到聚焦手势，聚焦坐标:x=%f y=%f", point.x, point.y);
    if(self.cameraMode == LLZBaseCameraModeCustom){
        if (point.y > CGRectGetMaxY(self.switchCameraButton.frame) && point.y < CGRectGetMinY(self.tipLabel.frame)) {
            [self setFocusCursorWithPoint:point];
            [self.captureTool setFocusWithPoint:point];
        }
    } else {
        [self setFocusCursorWithPoint:point];
        [self.captureTool setFocusWithPoint:point];
    }
}

// 设置聚焦功能并产生动画
-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusImageView.center = point;
    self.focusImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    [UIView animateWithDuration:0.2 animations:^{
        self.focusImageView.alpha = 1;
        self.focusImageView.transform = CGAffineTransformMakeScale(1, 1);
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.focusImageView.alpha = 1;
        });
    }];
}


#pragma mark -缩放手势

- (void)addPinchGestureRecognizer {
    //添加捏合手势
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinch.delegate = self;
    [self.captureView addGestureRecognizer:pinch];
}


- (void)handlePinchGesture:(UIPinchGestureRecognizer *)pinch{
    if(self.captureTool.isRecording){
        return;
    }
    if(pinch.state == UIGestureRecognizerStateBegan) {
        self.currentZoomFactor = self.captureTool.videoZoomFactor;
    }
    if (pinch.state == UIGestureRecognizerStateChanged) {
        self.captureTool.videoZoomFactor = self.currentZoomFactor * pinch.scale;
        NSLog(@"自定义相机已接收到缩放手势，缩放系数%f", self.captureTool.videoZoomFactor);
    }
}


#pragma mark - getters & setters


- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        _containerView.backgroundColor = [UIColor blackColor];
    }
    return _containerView;
}


- (UIView *)captureView {
    if (!_captureView) {
        switch (_cameraMode) {
            case LLZBaseCameraModeDefault: {
                CGFloat captureViewHeight = self.view.frame.size.height-kHeightOfBottomViewForDefaultCamera;
                if (@available(iOS 11.0, *)) {
                    captureViewHeight = captureViewHeight - self.view.safeAreaInsets.bottom;
                }
                _captureView = [[UIView alloc] initWithFrame: CGRectMake(0 ,0, self.view.frame.size.width, captureViewHeight)];
                break;
            }
            case LLZBaseCameraModeCustom:
                _captureView = [[UIView alloc] initWithFrame: CGRectMake(0 ,0, self.view.frame.size.width, self.view.frame.size.height)];
                break;
        }
        // 添加捏合手势
        [self addPinchGestureRecognizer];
        [self addFocusGestureRecognizer];
        [_captureView addSubview:self.focusImageView];
    }
    return _captureView;
}

- (UIButton *)toggleFlashButton {
    if(!_toggleFlashButton){
        _toggleFlashButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _toggleFlashButton.backgroundColor = [UIColor clearColor];
        UIImage *icon = self.captureTool.flashMode ? [self bundleWithImageName:@"camera_flash_on"] : [self bundleWithImageName:@"camera_flash_off"];
        [_toggleFlashButton setImage:icon forState:UIControlStateNormal];
        [_toggleFlashButton addTarget:self action:@selector(didClickSwitchFlashModeButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _toggleFlashButton;
}

- (UIButton *)toggleTorchButton {
    if(!_toggleTorchButton){
        _toggleTorchButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _toggleTorchButton.backgroundColor = [UIColor clearColor];
        UIImage *icon = self.captureTool.torchMode ? [self bundleWithImageName:@"icon_light_on"] : [self bundleWithImageName:@"icon_light_off"];
        [_toggleTorchButton setImage:icon forState:UIControlStateNormal];
        [_toggleTorchButton addTarget:self action:@selector(didClickSwitchTorchModeButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _toggleTorchButton;
}

- (UIButton *)switchCameraButton {
    if(!_switchCameraButton){
        _switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _switchCameraButton.backgroundColor = [UIColor clearColor];
        [_switchCameraButton setImage:[self bundleWithImageName:@"camera_switch"] forState:UIControlStateNormal];
        [_switchCameraButton addTarget:self action:@selector(didClickSwitchCameraButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchCameraButton;
}

- (UIView *)captureBtn {
    if (!_captureBtn) {
        switch (_cameraMode) {
            case LLZBaseCameraModeCustom:{
                _captureBtn = [[UIView alloc] init];
                CGFloat scale = [UIScreen mainScreen].bounds.size.width/375;
                CGFloat width = 60.0*scale;
                CGFloat startY = self.containerView.frame.size.height - 134*scale;
                if (@available(iOS 11.0, *)) {
                    startY = startY - self.view.safeAreaInsets.bottom;
                }
                _captureBtn.frame = CGRectMake((self.containerView.frame.size.width - width)/2, startY , width, width);
                [_captureBtn.layer setCornerRadius:_captureBtn.frame.size.width/2];
                _captureBtn.backgroundColor = [UIColor whiteColor];
                if(_allowRecording){
                    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(didReceiveRecordGestureRecognizer:)];
                    press.delegate = self;
                    [_captureBtn addGestureRecognizer:press];
                }
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didClickCaptureButton)];
                [_captureBtn addGestureRecognizer:tap];
                break;
            }
            case LLZBaseCameraModeDefault:{
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                UIImage *image = nil;
                image = [self bundleWithImageName:@"icon_imagePicker_camera"];
                [button setImage:image forState:UIControlStateNormal];
                button.frame = CGRectMake(0, 0, 54, 54);
                button.center = CGPointMake(self.controlsView.center.x, CGRectGetHeight(self.controlsView.frame)/2);
                [button addTarget:self action:@selector(didClickCaptureButton) forControlEvents:UIControlEventTouchUpInside];
                _captureBtn = button;
                _captureBtn.userInteractionEnabled = YES;
                break;
            }
        }
    }
    return _captureBtn;
}
- (UIView *)captureBtnBGView{
    if (!_captureBtnBGView) {
        CGRect rect = self.captureBtn.frame;
        CGFloat gap = 7.5;
        rect.size = CGSizeMake(rect.size.width + gap*2, rect.size.height + gap*2);
        rect.origin = CGPointMake(rect.origin.x - gap, rect.origin.y - gap);
        _captureBtnBGView = [[UIView alloc] initWithFrame:rect];
        _captureBtnBGView.backgroundColor = [UIColor whiteColor];
        _captureBtnBGView.alpha = 0.6;
        [_captureBtnBGView.layer setCornerRadius:_captureBtnBGView.frame.size.width/2];
    }
    return _captureBtnBGView;
}
- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.captureBtnBGView.frame.origin.y - 30, self.containerView.frame.size.width, 20)];
        _tipLabel.textColor = [UIColor whiteColor];
        _tipLabel.text = _allowRecording ? @"轻触拍照，按住摄像" : @"轻触拍照";
        _tipLabel.font = [UIFont systemFontOfSize:12];
        _tipLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _tipLabel;
}

- (UIButton *)dismissButton{
    if (!_dismissButton) {
        switch (_cameraMode) {
            case LLZBaseCameraModeCustom:{
                _dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
                UIImage *image = [self bundleWithImageName:@"camera_capture_back"];
                [_dismissButton setImage:image forState:UIControlStateNormal];
                _dismissButton.frame = CGRectMake(60, self.captureBtn.center.y - 18, 36, 36);
                [_dismissButton addTarget:self action:@selector(didClickDismissButton) forControlEvents:UIControlEventTouchUpInside];
                break;
            }
            case LLZBaseCameraModeDefault:{
                _dismissButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, CGRectGetHeight(self.controlsView.frame))];
                [_dismissButton addTarget:self action:@selector(didClickDismissButton) forControlEvents:UIControlEventTouchUpInside];
                [_dismissButton setTitle:@"返回" forState:UIControlStateNormal];
                [_dismissButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                _dismissButton.titleLabel.font = [UIFont systemFontOfSize:16];
                break;
            }
        }
    }
    return _dismissButton;
}

- (LLZCameraRecordProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[LLZCameraRecordProgressView alloc] initWithFrame:self.captureBtnBGView.frame];
    }
    return _progressView;
}


- (UIImageView *)focusImageView{
    if (!_focusImageView) {
        UIImage *image = [self bundleWithImageName:@"camera_capture_focus"];
        _focusImageView = [[UIImageView alloc] initWithImage:image];
        _focusImageView.alpha = 0;
        _focusImageView.frame = CGRectMake(0, 0, 75, 75);
    }
    return _focusImageView;
}



#pragma mark - private methods
// 取消已经录制的视频
- (void)cancelPlayerView {
    self.inLoopPlay = NO;
    [self restartCamera];
}

// 更新相机控件显示/隐藏状态
- (void)updateUI {
    _captureBtn.userInteractionEnabled = YES;
    if(_cameraMode == LLZBaseCameraModeCustom){
        _captureBtn.transform = CGAffineTransformMakeScale(1, 1);
        _captureBtnBGView.transform = CGAffineTransformMakeScale(1, 1);
        _captureBtnBGView.hidden = NO;
        _captureBtn.hidden = NO;
    }
    _dismissButton.hidden = NO;
    _tipLabel.hidden = NO;
    if(_switchCameraButton){
        _switchCameraButton.hidden = NO;
    }
    if(_toggleTorchButton){
        [self updateTorchBtnIcon];
        _toggleTorchButton.hidden = NO;
    }
    if(_toggleFlashButton){
        [self updateFlashBtnIcon];
        _toggleFlashButton.hidden = NO;
    }

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)restartCamera {
    [self updateUI];
    dispatch_async(self.sessionQueue, ^{
        [self.captureTool startRunning];
    });
}

- (void)dismiss {
    [self dismissViewControllerAnimated:NO completion:nil];
}

// 读取图片素材
- (UIImage *)bundleWithImageName:(NSString *)imageName {
    UIImage *image = nil;
    if (imageName) {
        NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"LLZCameraResources" withExtension:@"bundle"];
        if(bundleURL) {
            NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
            image = [UIImage imageNamed:imageName inBundle:bundle compatibleWithTraitCollection:nil];
            return image;
        }
    }
    return nil;
}

// 压缩失败 - 弹窗
- (void)showCompressFailedAlert {
    NSString *errorMsg = @"视频压缩失败,请重新录制";
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }];
        
        [alert addAction:cancelAction];
        
        UIViewController *vc = [UIViewController currentViewController];
        [vc presentViewController:alert animated:YES completion:nil];
        [self cancelPlayerView];
    });
    NSLog(@"视频压缩失败");
}


// 允许多手势识别
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}


@end
