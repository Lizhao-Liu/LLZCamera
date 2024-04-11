//
//  LLZCameraPlayerView.h
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/16.
//

#import <UIKit/UIKit.h>
#import "LLZCameraCaptureFileCacheManager.h"

NS_ASSUME_NONNULL_BEGIN

@class LLZCameraPlayerView;
@protocol LLZCameraPlayerViewDelegate <NSObject>

// 点击取消
- (void)didClickCancelWithLLZCameraPlayerView:(LLZCameraPlayerView *)view fileURL:(NSURL *)fileURL fileType:(LLZCameraOutputFileType)fileType;
// 点击确定
- (void)didClickConfirmWithLLZCameraPlayerView:(LLZCameraPlayerView *)view fileURL:(NSURL *)fileURL fileType:(LLZCameraOutputFileType)fileType;

@end


@interface LLZCameraPlayerView : UIView

@property (nonatomic, weak) id<LLZCameraPlayerViewDelegate> delegate;

/**
 播放视频初始化方法（兼容图片格式）

 @param frame frame
 @param url 本地播放视频url（或本地图片URL）
 @return return value description
 */
- (instancetype)initWithFrame:(CGRect)frame url:(NSURL *)url fileType:(LLZCameraOutputFileType)fileType needAutoFitImageSize:(BOOL)needAutoFit;

@end

NS_ASSUME_NONNULL_END
