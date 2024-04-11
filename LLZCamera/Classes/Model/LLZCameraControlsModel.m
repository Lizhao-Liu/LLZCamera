//
//  LLZCameraControlsModel.m
//  AAChartKit
//
//  Created by Lizhao on 2022/12/9.
//

#import "LLZCameraControlsModel.h"

@implementation LLZCameraControlsVideoModel

@end

@implementation LLZCameraControlsModel

+ (instancetype) defaultControlOptions {
    LLZCameraControlsModel *options = [[LLZCameraControlsModel alloc] init];
    options.needFlashSwitch = YES;
    options.needTorchSwitch = YES;
    options.needCameraSwitch = YES;
    options.needAutoLightDetection = YES;
    options.startWithFrontCamera = NO;
    return options;
}

@end
