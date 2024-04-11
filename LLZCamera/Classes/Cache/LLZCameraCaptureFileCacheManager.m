//
//  LLZCameraCaptureFileCachePool.m
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import "LLZCameraCaptureFileCacheManager.h"
@import AVFoundation;

@implementation LLZCameraCaptureFileCacheManager

// 图片写入本地缓存文件目录
+ (NSString *)writeToLocalCacheFilePathWithImageData:(NSData *)data {
    NSString *cacheDirectory = [self getCacheDirWithCreate:YES];
    NSTimeInterval time = [[NSDate dateWithTimeIntervalSinceNow:0] timeIntervalSince1970];
    NSString *timeStr = [NSString stringWithFormat:@"%.0f", time];
    NSString *fileName = [NSString stringWithFormat:@"photo_%@.jpeg", timeStr];
    NSString *filePath = [cacheDirectory stringByAppendingPathComponent:fileName];
    BOOL result = [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
    return result == YES ? filePath : nil;
}


// 获取缓存文件路径
+ (NSString*)cacheFilePath:(BOOL)input {
    NSString *cacheDirectory = [self getCacheDirWithCreate:YES];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HHmmss"];
    NSDate *NowDate = [NSDate dateWithTimeIntervalSince1970:now];
    NSString *timeStr = [formatter stringFromDate:NowDate];
    NSString *put = input ? @"input" : @"output";
    NSString *path = input ? @"mov" : @"mp4";
    NSString *fileName = [NSString stringWithFormat:@"video_%@_%@.%@",timeStr,put,path];
    return [cacheDirectory stringByAppendingFormat:@"/%@", fileName];
}

// 获取文件大小
+ (CGFloat)getfileSize:(NSString *)filePath{
    NSFileManager *fm = [NSFileManager defaultManager];
    filePath = [filePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    CGFloat fileSize = 0;
    if ([fm fileExistsAtPath:filePath]) {
        fileSize = [[fm attributesOfItemAtPath:filePath error:nil] fileSize];
//        NSLog(@"视频大小 - - - - - %fM,--------- %fKB",fileSize / (1024.0 * 1024.0),fileSize / 1024.0);
    }
    return fileSize/1024/1024;
}

// 获取缓存目录
+ (NSString *)getCacheDirWithCreate:(BOOL)isNeedCreate {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths objectAtIndex:0];
    dir = [dir stringByAppendingPathComponent:@"Caches"];
    dir = [dir stringByAppendingPathComponent:@"LLZCameraCache"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir]) {
        // 不存在
        if (isNeedCreate) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
            NSLog(@"已自动生成缓存目录:%@", dir);
            return dir;
        }else {
            return @"";
        }
    }else{
        // 存在
        return dir;
    }
}

+ (void)cleanCacheFiles {
    NSString *cacheDirectory = [self getCacheDirWithCreate:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:cacheDirectory error:NULL];
    NSLog(@"相机捕获文件缓存已清空");
}

// 获取本地视频封面缩略图
+ (UIImage *)getThumbnailImageWithFilePath:(NSURL *)videoURL time:(NSTimeInterval)time {
    if (!videoURL) return nil;
    
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:videoURL options:opts];
    
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    generator.appliesPreferredTrackTransform = YES;
    generator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    generator.maximumSize = CGSizeMake(640., 480.);
    
    CGImageRef imgRef = [generator copyCGImageAtTime:CMTimeMake(0, 10) actualTime:NULL error:nil];
    if (imgRef) {
        return [UIImage imageWithCGImage:imgRef];
    }
    
    return nil;
}

// 获取本地视频总时长
+ (NSUInteger)getVideoTotalDurationSecondsWithUrl:(NSURL *)fileUrl {
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                     forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:fileUrl options:opts];
    NSUInteger seconds =  (NSUInteger)(urlAsset.duration.value / urlAsset.duration.timescale);
    seconds = seconds<=0 ? 1 : seconds;
    
    return seconds;
}

+ (LLZCameraOutputFileType)getFileTypeWithFileURL:(NSURL *)fileURL {
    if (fileURL == nil) { return LLZCameraCaptureFileType_Unknown; }
    return [fileURL.absoluteString hasSuffix:@"jpeg"] ? LLZCameraCaptureFileType_Image : LLZCameraCaptureFileType_Video;
}


// 视频压缩并输出到指定路径
+ (void)compressVideoWithFileURL:(NSURL *)url complete:(void (^)(BOOL success, NSURL *url))complete {
    // 输入路径
    NSURL *inputUrl = url;
    // 输出路径
    NSURL *outputUrl = [NSURL fileURLWithPath:[self cacheFilePath:NO]];
    // 压缩
    [self convertVideoQuailtyWithInputURL:inputUrl outputURL:outputUrl completeHandler:^(AVAssetExportSession *exportSession) {
        complete(exportSession.status == AVAssetExportSessionStatusCompleted , outputUrl);
    }];
}

// 压缩视频质量，并输出到指定文件目录
+ (void)convertVideoQuailtyWithInputURL:(NSURL*)inputURL outputURL:(NSURL*)outputURL completeHandler:(void (^)(AVAssetExportSession*))handler{
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetPassthrough];
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        handler(exportSession);
    }];
}


@end
