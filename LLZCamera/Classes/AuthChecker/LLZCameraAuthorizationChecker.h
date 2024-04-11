//
//  LLZCameraAuthorizationChecker.h
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLZCameraAuthorizationChecker : NSObject

/**
 获取是否具有摄像头访问权限

 @param isAuthorized 权限
 */
+ (void)getCameraAuthorization:(void(^)(BOOL granted))isAuthorized;

/**
 获取是否具有麦克风访问权限

 @param isAuthorized 权限
 */
+ (void)getMicrophoneAuthorization:(void(^)(BOOL granted))isAuthorized;

@end

NS_ASSUME_NONNULL_END
