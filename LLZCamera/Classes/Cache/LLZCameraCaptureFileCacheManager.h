//
//  LLZCameraCaptureFileCachePool.h
//  YMMImagePicker
//
//  Created by Lizhao on 2022/12/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 录制文件格式类型
typedef NS_ENUM(NSUInteger, LLZCameraOutputFileType) {
    LLZCameraCaptureFileType_Unknown, // 未知
    LLZCameraCaptureFileType_Video,   // 视频文件
    LLZCameraCaptureFileType_Image    // 图片文件
};

@interface LLZCameraCaptureFileCacheManager : NSObject

/**
 图片写入本地缓存文件目录

 @param data 图片数据
 @return 路径
 */
+ (NSString *)writeToLocalCacheFilePathWithImageData:(NSData *)data;


/**
 获取输出文件路径

 @param input 输出
 @return 路径
 */
+ (NSString*)cacheFilePath:(BOOL)input;


/**
 清空缓存

 */
+ (void)cleanCacheFiles;


/**
 获取文件大小

 @param filePath 文件路径
 @return 文件大小
 */
+ (CGFloat)getfileSize:(NSString *)filePath;


/**
 获取缓存目录

 @param isNeedCreate 如果不存在是否需要新建
 @return 文件大小
 */
+ (NSString *)getCacheDirWithCreate:(BOOL)isNeedCreate;


/**
 压缩视频

 @param url 待压缩的本地视频地址url
 @param complete 压缩回调
 */
+ (void)compressVideoWithFileURL:(NSURL *)url complete:(void (^)(BOOL success, NSURL *url))complete;



/**
 获取本地视频封面图

 @param videoURL 本地视频地址
 @param time 截取某一刻
 @return 截图
 */
+ (UIImage *)getThumbnailImageWithFilePath:(NSURL *)videoURL time:(NSTimeInterval)time;


/**
 获取本地视频总时长

 @param fileUrl 本地视频路径
 @return 总时长，单位秒
 */
+ (NSUInteger)getVideoTotalDurationSecondsWithUrl:(NSURL *)fileUrl;


/**
 获取文件格式类型

 @param fileURL 文件资源绝对路径
 @return 文件格式
 */
+ (LLZCameraOutputFileType)getFileTypeWithFileURL:(NSURL *)fileURL;


@end

NS_ASSUME_NONNULL_END
