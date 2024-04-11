//
//  LLZCameraCaptureTool.h
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@class LLZCameraCaptureTool;

@protocol LLZCameraCaptureToolDelegate <NSObject>

/**
 录制过程回调
 
 @param recordTime 当前录制时长
 @param totalTime 最大录制时长
 */
- (void)captureTool:(LLZCameraCaptureTool *)captureTool didFinishVideoRecordingOfCurrentTime:(CGFloat)recordTime withTotalTime:(CGFloat)totalTime;

/**
 录制结束

 @param captureOutput 录制文件输出
 @param outputFileURL 本地输出路径
 @param connections connections description
 @param error error description
 */
- (void)captureTool:(LLZCameraCaptureTool *)captureTool didFinishRecordingWithOutput:(AVCaptureFileOutput *)captureOutput atURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;


/**
 监测到拍摄过程中设备方向转变
 */
- (void)captureTool:(LLZCameraCaptureTool *)captureTool deviceOrientationDidChange:(UIDeviceOrientation)orientation;

@end


typedef void (^PhotoCapturedBlock)(NSURL *fileURL);

typedef void (^TorchModeChangedBlock)(void);

/// 摄像头采集工具
@interface LLZCameraCaptureTool : NSObject

// 捕获工具代理
@property (nonatomic, weak) id<LLZCameraCaptureToolDelegate> delegate;

// 摄像头实时输出图层
@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *captureLayer;
/// 摄像头是否正在运行
@property (nonatomic, assign, readonly) BOOL isRunning;
/// 是否正在录制视频
@property (nonatomic, assign, readonly) BOOL isRecording;
/// 摄像头方向 默认后置摄像头
@property (nonatomic, assign, readonly) AVCaptureDevicePosition devicePosition;
// 相机手电筒模式
@property (nonatomic, assign, readonly) AVCaptureTorchMode torchMode;
// 相机闪光灯模式
@property (nonatomic, assign) AVCaptureFlashMode flashMode;
/// 当前焦距    默认最小值1  最大值6
@property (nonatomic, assign) CGFloat videoZoomFactor;

// 最长录制时间 默认30s
@property (nonatomic, assign) CGFloat videoMaximumDuration;


#pragma mark - output configuration
@property (nonatomic, assign) BOOL needFixPhotoOrientation; //默认为no
@property (nonatomic, assign) BOOL needAdjustVideoMirroring; //默认为no
// 自定义相片输出方向
@property (nonatomic, copy) AVCaptureVideoOrientation (^PhotoOutputOrientationBlock)(UIDeviceOrientation deviceOrientation);


+ (instancetype)captureToolForTakingPhotoWithCamera:(AVCaptureDevicePosition)devicePosition;

+ (instancetype)captureToolForRecordingVideoWithCamera:(AVCaptureDevicePosition)devicePosition;

- (void)startRunning;

- (void)stopRunning;

/**
 配置后台播放音频
 */
- (void)configureAVAudioSessionInBackgroundMode;

/**
 初始化配置音视频会话
 */

- (void)configureAVCaptureSession;

/**
 拍照

 @param completion 捕获照片回调
 */
- (void)takePhotoWithCompletion:(PhotoCapturedBlock)completion;

/**
 开始录制

 @param outputFile 输出文件地址
 */
- (void)startRecordingVideoToFileURL:(NSURL *)outputFile;

/**
 停止录制
 */
- (void)stopRecordingVideo;


/**
 切换摄像头
 */
- (void)switchCamera;

/**
 设置聚焦
 
 @param point 聚焦点
 */
- (void)setFocusWithPoint:(CGPoint)point;

/**
 切换闪光灯状态
 
 */
- (void)switchFlashMode;


- (void)switchTorchMode;


/**
  增加自动识别光线开启手电筒功能
 */
- (void)addAutoLightDetectionWithTorchModeChangedBlock:(TorchModeChangedBlock)block;


@end

NS_ASSUME_NONNULL_END
