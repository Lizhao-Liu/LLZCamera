//
//  LLZCameraControlsModel.h
//
//  Created by Lizhao on 2022/12/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLZCameraControlsVideoModel : NSObject

@property (nonatomic, assign) BOOL allowRecording;
@property (nonatomic, assign) BOOL needPreview;
@property (nonatomic, assign) BOOL autoCloseOnCapture;
@property (nonatomic, assign) NSInteger videoMinimumDuration;
@property (nonatomic, assign) NSInteger videoMaximumDuration;

@end

@interface LLZCameraControlsModel : NSObject

// 需要切换摄像头选项
@property (nonatomic, assign) BOOL needCameraSwitch;

// 需要闪光灯选项
@property (nonatomic, assign) BOOL needFlashSwitch;

// 需要手电筒选项
@property (nonatomic, assign) BOOL needTorchSwitch;

// 需要根据环境光线自动调整手电筒状态 - 可录制视频模式下不支持开启
@property (nonatomic, assign) BOOL needAutoLightDetection;

// 是否需要初始照相机使用前置摄像头
@property (nonatomic, assign) BOOL startWithFrontCamera;

+ (instancetype)defaultControlOptions;

@end


NS_ASSUME_NONNULL_END
