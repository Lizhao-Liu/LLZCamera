//
//  UIViewController+Utils.m
//  YMMImagePicker
//
//  Created by zhaozhao on 2024/4/9.
//

#import "UIViewController+Utils.h"

@implementation UIViewController (Utils)


+ (nullable UIViewController *)currentViewController {
    UIViewController *resultVC;
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows) {
            if (tmpWin.windowLevel == UIWindowLevelNormal) {
                window = tmpWin;
                break;
            }
        }
    }
    
    if ([window subviews].count == 0) {
        return nil;
    }
    
    UIView *frontView = [[window subviews] objectAtIndex:0];
    id nextResponder = [frontView nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        resultVC = nextResponder;
    } else {
        resultVC = window.rootViewController;
    }
    
    BOOL isContinue = YES;
    
    while (isContinue) {
        if ([resultVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)resultVC;
            if (navController.visibleViewController) {
                resultVC = navController.visibleViewController;
            } else if (navController.topViewController) {
                resultVC = navController.topViewController;
            } else {
                isContinue = NO;
            }
        } else if (resultVC.presentedViewController) {
            // 20220223对于不正确使用的UINavigationVC兼容
            UIViewController *tempVC = resultVC;
            resultVC = resultVC.presentedViewController;
            
            if ([resultVC isKindOfClass:[UINavigationController class]]) {
                if ([(UINavigationController*)resultVC visibleViewController] || [(UINavigationController*)resultVC topViewController]) {
                    // 20220223对于不正确使用的UINavigationVC兼容
                    // 具体是RN的一些presented出了UINavigationVC，但是视图等直接放在nav的view上，不遵循nav的root，push，pop等
                    // 针对这种情况还是返回之前的vc，此方法不返回这个不合理的nav
                } else {
                    resultVC = tempVC;
                    isContinue = NO;
                }
            }
        } else {
            isContinue = NO;
        }
    }
    
    return resultVC;
}

@end
