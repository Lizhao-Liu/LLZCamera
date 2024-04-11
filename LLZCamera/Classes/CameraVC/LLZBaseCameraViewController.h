//
//  LLZCustomBaseCameraViewController.h
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import <UIKit/UIKit.h>
@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@class LLZBaseCameraViewController;

/// 相机回调delegate
@protocol LLZBaseCameraViewControllerDelegate <NSObject>


/// 点击取消回调
/// @param vc 相机vc
- (void)didClickCancelWithLLZCameraViewController:(LLZBaseCameraViewController *)vc;


/// 拍照完成回调
/// @param vc 相机vc
/// @param photoImageData 原始图片数据
/// @param image 结果图片
- (void)didCapturePhotoWithLLZCameraViewController:(LLZBaseCameraViewController *)vc
                                originalPhotoData:(NSData *)photoImageData
                                            image:(UIImage *)image;


/// 录像完成回调
/// @param vc 相机vc
/// @param fileURL 视频文件缓存地址url（相机关闭后会清空文件缓存）
/// @param aDuration 视频文件时长
/// @param thumbnailImage 视频文件缩略图
- (void)didCaptureVideoWithLLZCameraViewController:(LLZBaseCameraViewController *)vc
                                          fileURL:(NSURL *)fileURL
                                         duration:(int)aDuration
                                   thumbnailImage:(UIImage *)thumbnailImage;

@end


typedef NS_ENUM(NSInteger, LLZBaseCameraMode) {
    LLZBaseCameraModeDefault, // 默认相机模式，仅支持拍照
    LLZBaseCameraModeCustom // 自定义全屏相机，可录像
};


@class LLZCameraControlsModel;
@class LLZCameraCaptureTool;

@interface LLZBaseCameraViewController : UIViewController

/// 初始化自定义全屏相机（支持录像，全屏）
/// @param controlOptions 相机参数
/// @param allowRecording 是否开启录像功能
- (instancetype)initCustomCameraWithControlOptions:(LLZCameraControlsModel *)controlOptions allowRecording:(BOOL)allowRecording;

/// 初始化默认相机（不支持录像，非全屏）
/// @param controlOptions 相机参数
- (instancetype)initDefaultCameraWithControlOptions:(LLZCameraControlsModel *)controlOptions;

// 相机模式 @see LLZBaseCameraMode
@property (nonatomic, assign) LLZBaseCameraMode cameraMode;

// 相机回调delegate
@property (nonatomic, weak) id<LLZBaseCameraViewControllerDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL isShowingCamera;

#pragma mark - 相机配置
// 是否允许录像
@property (nonatomic, assign) BOOL allowRecording; //只有在LLZBaseCameraModeCustom下，支持开启录像功能
// 相机功能选项配置
@property (nonatomic, strong) LLZCameraControlsModel *controlOptions;
// 拍摄结束是否展示预览界面, 默认为no
@property (nonatomic, assign) BOOL needPreview;
// 拍摄结束是否需要保存图片/视频到相册， 默认为no
@property (nonatomic, assign) BOOL needSaveToAlbum;
// 拍摄结束是否需要自动关闭相机，默认为yes
@property (nonatomic, assign) BOOL autoCloseOnCapture;


#pragma mark - 输出配置
// 允许录制模式下，最短录制时间 默认5s
@property (nonatomic, assign) CGFloat videoMinimumDuration;
// 允许录制模式下，最长录制时间 默认30s
@property (nonatomic, assign) CGFloat videoMaximumDuration;
// 输出相片大小, 如果为nil默认使用原图大小输出
@property (nonatomic, assign) CGFloat cameraMaxPixelSize;
// 是否需要调整图片输出方向，如果开启，默认将横屏图片自动转换至竖屏返回
@property (nonatomic, assign) BOOL needFixPhotoOrientation;
// 根据设备方向，自定义图片输出方向
@property (nonatomic, copy) AVCaptureVideoOrientation (^PhotoOutputOrientationBlock)(UIDeviceOrientation deviceOrientation);
// 设置是否为镜像，前置摄像头采集到的数据本来就是翻转的，这里设置是否镜像把画面转回来，默认为YES
@property (nonatomic, assign) BOOL needAdjustVideoMirroring;

#pragma mark - UI
// 相机捕获视图
@property (nonatomic, strong) UIView *captureView;
// 操作层视图
@property (nonatomic, strong) UIView *controlsView;
// 相机蒙版配置
@property (nonatomic, strong, readonly) UIView *cameraMaskView; //相机显示蒙版视图，通过setMaskViewWithFrame方法设置蒙层视图
@property (nonatomic, copy) NSString *cameraMaskTipString; //相机显示蒙层提示
// 切换摄像头按钮
@property (nonatomic, strong) UIButton *switchCameraButton;

// 切换闪光灯按钮
@property (nonatomic, strong) UIButton *toggleFlashButton;

// 切换手电筒按钮
@property (nonatomic, strong) UIButton *toggleTorchButton;
// 相机捕获工具
@property (nonatomic, strong) LLZCameraCaptureTool *captureTool;

#pragma mark - 相机子类可自定义方法
//设置蒙层视图
- (UIView *)setMaskViewWithFrame:(CGRect)frame withTipString:(NSString *)tipString;
- (void)didClickCaptureButton;
- (void)didReceiveRecordGestureRecognizer:(UILongPressGestureRecognizer *)gesture;
- (void)didClickDismissButton;
- (void)didClickSwitchFlashModeButton;
- (void)didClickSwitchTorchModeButton;
- (void)didClickSwitchCameraButton;
// 当前设备方向发生转变的回调方法
- (void)deviceOrientationDidChange:(UIDeviceOrientation)orientation;
// 相机控件视图在不同设备方向下的旋转角度
- (CGFloat)rotationAngleForDeviceOrientation:(UIDeviceOrientation)orientation;

@end

NS_ASSUME_NONNULL_END
