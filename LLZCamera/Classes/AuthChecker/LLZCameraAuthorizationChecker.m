//
//  LLZCameraAuthorizationChecker.m
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import "LLZCameraAuthorizationChecker.h"
#import "UIViewController+Utils.h"
@import AVFoundation;

@implementation LLZCameraAuthorizationChecker

// 获取是否具有摄像头访问权限
+ (void)getCameraAuthorization:(void(^)(BOOL granted))isAuthorized {
#if TARGET_IPHONE_SIMULATOR
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isAuthorized) {
            isAuthorized(NO);
        }
        [self showDeviceErrorWithMessage:@"模拟器不支持访问摄像头"];
    });
#elif TARGET_OS_IPHONE
    if ([self isCameraAvaliable]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            switch (status) {
                case AVAuthorizationStatusDenied:
                case AVAuthorizationStatusRestricted: {
                    __weak __typeof(self)weakSelf = self;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        if (isAuthorized) {
                            isAuthorized(NO);
                        }
                        [strongSelf showNotAllowedAccessCameraAlert];
                    });
                }
                    break;
                case AVAuthorizationStatusNotDetermined: {
                    __weak __typeof(self)weakSelf = self;
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (isAuthorized) {
                                isAuthorized(granted);
                            }
                            if (!granted) {
                                __strong __typeof(weakSelf)strongSelf = weakSelf;
                                [strongSelf showNotAllowedAccessCameraAlert];
                            }
                        });
                    }];
                }
                    break;
                case AVAuthorizationStatusAuthorized: {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (isAuthorized) {
                            isAuthorized(YES);
                        }
                    });
                }
                    break;
                default:
                    break;
            }
        });
    } else {
        [self showDeviceErrorWithMessage:@"摄像头暂不可用"];
    }
#endif
}

// 获取是否具有麦克风访问权限
+ (void)getMicrophoneAuthorization:(void(^)(BOOL granted))isAuthorized {
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak __typeof(self)weakSelf = self;
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isAuthorized) {
                    isAuthorized(granted);
                    if (!granted) {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        [strongSelf showNotAllowedAccessMicrophoneAlert];
                    }
                }
            });
        }];
    });
}



+ (BOOL)isCameraAvaliable {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

+ (BOOL)isFrontCameraAvaliable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

+ (BOOL)isRearCameraAvaliable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}


+ (void)showDeviceErrorWithMessage:(NSString *)errorMsg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }];
        
        [alert addAction:ok];
        
        UIViewController *vc = [UIViewController currentViewController];
        [vc presentViewController:alert animated:YES completion:nil];
    });
}

// 展示相机权限拒绝弹框
+ (void)showNotAllowedAccessCameraAlert {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"%@申请您的相机权限，为确保相机功能的正常使用，请在iPhone的“设置-隐私-相机”选项中进行设置", appName];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法使用相机" message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            }
        }];
        
        [alert addAction:cancel];
        [alert addAction:ok];
        
        UIViewController *vc = [UIViewController currentViewController];
        [vc presentViewController:alert animated:YES completion:nil];
    });
}

// 展示麦克风权限拒绝弹框
+ (void)showNotAllowedAccessMicrophoneAlert {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"%@申请您的麦克风权限，为确保视频录制时麦克风正常使用，请在iPhone的“设置-隐私-麦克风”选项中进行设置", appName];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法使用麦克风" message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            }
        }];
        
        [alert addAction:cancel];
        [alert addAction:ok];
        
        UIViewController *vc = [UIViewController currentViewController];
        [vc presentViewController:alert animated:YES completion:nil];
    });
}


@end
