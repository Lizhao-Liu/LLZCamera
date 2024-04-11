//
//  LLZCameraPlayerView.m
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/16.
//

#import "LLZCameraPlayerView.h"
@import AVFoundation;

// 按钮从中间展开到两边的动画时长
static NSTimeInterval kLLZCameraVideoRecordPlayerView_ShowBtnsAnimationDuration = 0.2;

@interface LLZCameraPlayerView ()

@property (nonatomic, strong) NSURL *url;

@property (nonatomic, strong) CALayer *playerLayer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *confirmButton;

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, assign) BOOL needAutoFit;

@property (nonatomic, assign) LLZCameraOutputFileType fileType;
@end

@implementation LLZCameraPlayerView

- (instancetype)initWithFrame:(CGRect)frame url:(NSURL *)url fileType:(LLZCameraOutputFileType)fileType needAutoFitImageSize:(BOOL)needAutoFit {
    if (self = [super initWithFrame:frame]) {
        self.url = url;
        self.fileType = fileType;
        self.needAutoFit = needAutoFit;
        self.backgroundColor = [UIColor blackColor];
        
        if (self.fileType == LLZCameraCaptureFileType_Image) {
            [self addSubview:self.imageView];

            NSData *data = [[NSFileManager defaultManager] contentsAtPath:url.relativePath];
            self.imageView.image = [UIImage imageWithData:data];
        } else {
            // 监听视频结束通知
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveVideoPlayFinishedNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
            
            // 监听App进入前台
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveApplicationBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
            
            // 添加自定义view
            [self.layer addSublayer:self.playerLayer];
            
            // 开始播放
            [self.player play];
        }
        
        [self addSubview:self.confirmButton];
        [self addSubview:self.cancelButton];
        
        // 展示按钮动画
        [self showPlayerButtonsWithAnimationDuration:kLLZCameraVideoRecordPlayerView_ShowBtnsAnimationDuration];
    }
    return self;
}

- (void)dealloc {
    [_player pause];
    if (_playerItem) {
        [_playerItem cancelPendingSeeks];
        _playerItem = nil;
    }
    if (_player) {
        _player = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 按钮点击事件

- (void)didClickCancelButton:(UIButton *)btn {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didClickCancelWithLLZCameraPlayerView:fileURL:fileType:)]) {
        [self.delegate didClickCancelWithLLZCameraPlayerView:self fileURL:self.url fileType:self.fileType];
    }
    [self.player pause];
    [self removeFromSuperview];
}

- (void)didClickConfirmButton:(UIButton *)btn {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didClickConfirmWithLLZCameraPlayerView:fileURL:fileType:)]) {
        [self.delegate didClickConfirmWithLLZCameraPlayerView:self fileURL:self.url fileType:self.fileType];
    }
    [self.player pause];
    [self removeFromSuperview];
}

#pragma mark - Private Methods

- (void)showPlayerButtonsWithAnimationDuration:(NSTimeInterval)duration {
    CGFloat scale = [UIScreen mainScreen].bounds.size.width/375.0;
    CGFloat width = 60.0*scale;
    CGRect cancelRect = self.cancelButton.frame;
    CGRect confirmRect = self.confirmButton.frame;
    cancelRect.origin.x = 60*scale;
    confirmRect.origin.x = self.frame.size.width - 60*scale - width;
    [UIView animateWithDuration:duration animations:^{
        self.cancelButton.frame = cancelRect;
        self.confirmButton.frame = confirmRect;
        self.confirmButton.alpha = 1;
        self.cancelButton.alpha = 1;
    }];
}

#pragma mark - NSNotification

- (void)didReceiveVideoPlayFinishedNotification:(NSNotification *)notification  {
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
}

- (void)didReceiveApplicationBecomeActiveNotification:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
}

#pragma mark - Getter

- (AVPlayer *)player {
    if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:self.playerItem];
    }
    return _player;
}

- (AVPlayerItem *)playerItem {
    if (!_playerItem) {
        _playerItem = [AVPlayerItem playerItemWithURL:self.url];
    }
    return _playerItem;
}

- (CALayer *)playerLayer {
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    layer.frame = self.bounds;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    return layer;
}

- (UIButton *)cancelButton {
    if (!_cancelButton) {
        CGFloat scale = [UIScreen mainScreen].bounds.size.width/375.0;
        CGFloat width = 65.0*scale;
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cancelButton.frame = CGRectMake((self.frame.size.width - width)/2, self.frame.size.height - 140*scale, width, width);
        UIImage *image = [self bundleWithImageName:@"icon_imagePicker_EditBack"];
        [_cancelButton setBackgroundImage:image forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(didClickCancelButton:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.alpha = 0;
    }
    return _cancelButton;
}

- (UIButton *)confirmButton {
    if (!_confirmButton) {
        CGFloat scale = [UIScreen mainScreen].bounds.size.width/375.0;
        CGFloat width = 65.0*scale;
        _confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        UIImage *image = [self bundleWithImageName:@"icon_imagePicker_editSubmit"];
        [_confirmButton setBackgroundImage:image forState:UIControlStateNormal];
        _confirmButton.frame = CGRectMake((self.frame.size.width - width)/2, self.cancelButton.frame.origin.y , width, width);
        [_confirmButton addTarget:self action:@selector(didClickConfirmButton:) forControlEvents:UIControlEventTouchUpInside];
        _confirmButton.alpha = 0;
    }
    return _confirmButton;
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        if(_needAutoFit){
            _imageView.contentMode = UIViewContentModeScaleAspectFit;
        } else {
            _imageView.contentMode = UIViewContentModeScaleAspectFill;
        }
    }
    return _imageView;
}

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

@end
