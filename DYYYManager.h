#pragma once
// 添加C++11支持声明，消除"Photos requires C++11 or later"错误
#if __cplusplus
#if __cplusplus < 201103L
#define __cplusplus 201103L
#endif
#endif

// 引入包含MediaType定义的头文件
#import "AwemeHeaders.h"

// 基础UIKit框架
#import <UIKit/UIKit.h>

// Photos 框架
#import <Photos/Photos.h>

// 其他框架
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

// 常量和类型定义
#define DYYY 100
#define kCGImagePropertyGIFImageCount CFSTR("ImageCount") // GIF 帧数常量

@interface DYYYManager : NSObject
// 存储文件链接
@property (nonatomic, strong) NSMutableDictionary *fileLinks;

+ (instancetype)shared;

// UI相关方法
+ (UIWindow *)getActiveWindow;
+ (UIViewController *)getActiveTopController;
+ (UIColor *)colorWithHexString:(NSString *)hexString;
+ (void)showToast:(NSString *)text;

// 媒体处理方法
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion;
+ (NSString *)getMediaTypeDescription:(MediaType)mediaType;
+ (MediaType)analyzeImageType:(NSURL *)url;
+ (MediaType)intelligentDetectMediaType:(NSURL *)url;

// 下载和媒体相关方法
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion;
+ (void)downloadMediaWithProgress:(NSURL *)url mediaType:(MediaType)mediaType progress:(void (^)(float))progressBlock completion:(void (^)(BOOL success, NSURL *fileURL))completionBlock;
+ (void)downloadAndSaveMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(NSURL *localFileURL, NSError *error))completion;
+ (void)cancelAllDownloads;

// 实况照片相关方法
+ (void)downloadLivePhoto:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(void))completion;
+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos;
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos progress:(void (^)(NSInteger current, NSInteger total))progressBlock completion:(void (^)(NSInteger successCount, NSInteger totalCount))completionBlock;
+ (void)downloadAndSaveLivePhotoWithImageURL:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(BOOL success, NSError *error))completion;
- (void)saveLivePhoto:(NSString *)imageSourcePath videoUrl:(NSString *)videoSourcePath;

// 批量下载图片
+ (void)downloadAllImages:(NSArray<NSString *> *)imageURLs;
+ (void)downloadAllImagesWithProgress:(NSArray<NSString *> *)imageURLs progress:(void (^)(NSInteger current, NSInteger total))progressBlock completion:(void (^)(NSInteger successCount, NSInteger totalCount))completionBlock;
+ (void)downloadAndSaveAllImages:(NSArray<NSString *> *)imageURLStrings completion:(void (^)(NSInteger successCount, NSInteger failureCount))completion;

// 视频处理方法
+ (void)convertImagesToVideo:(NSArray<NSString *> *)imageURLStrings completion:(void (^)(NSURL *videoURL))completion;
+ (void)saveVideoToAlbum:(NSURL *)videoURL completion:(void (^)(void))completion;
+ (CGSize)getOptimalVideoSizeFromImages:(NSArray<NSURL *> *)imageURLs;

// 图片处理方法
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size;

@end
