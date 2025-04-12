// DYYYManager.m
#import "DYYYManager.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <CoreMedia/CoreMedia.h>  // 添加 CoreMedia 框架导入
#import <AVFoundation/AVFoundation.h> // 音视频框架
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h> // 统一类型标识符框架

// 如果 CoreMedia 框架导入后仍然找不到 kCMMetadataBaseDataType_SInt8 常量
#ifndef kCMMetadataBaseDataType_SInt8
#define kCMMetadataBaseDataType_SInt8 CFSTR("sint8")
#endif

#ifndef kCGImagePropertyHEICSDictionary
#define kCGImagePropertyHEICSDictionary (__bridge CFStringRef)@"HEICSDictionary"
#endif

#ifndef kCGImagePropertyHEICSDDelayTime 
#define kCGImagePropertyHEICSDDelayTime (__bridge CFStringRef)@"DelayTime"
#endif

// 自定义进度条视图类
@interface DYYYManager(){
    AVAssetExportSession *session;
    AVURLAsset *asset;
    AVAssetReader *reader;
    AVAssetWriter *writer;
    dispatch_queue_t queue;
    dispatch_group_t group;
}
@end

// 下载进度视图类
@interface DYYYDownloadProgressView : UIView
@property (nonatomic, strong) UIView *containerView;        // 容器视图 (居中的那个深色背景块)
@property (nonatomic, strong) UIView *progressBarBackground;// 进度条背景 (灰色长条)
@property (nonatomic, strong) UIView *progressBar;          // 进度条 (蓝色填充部分)
@property (nonatomic, strong) UILabel *progressLabel;       // 进度文字 (例如 "50%")
@property (nonatomic, strong) UIButton *cancelButton;       // 取消按钮
@property (nonatomic, copy) void (^cancelBlock)(void);      // 取消按钮的回调 Block
@property (nonatomic, assign) BOOL isCancelled;             // 标记是否已被用户取消
- (instancetype)initWithFrame:(CGRect)frame;        // 初始化方法
- (void)setProgress:(float)progress;                // 设置进度 (0.0 ~ 1.0)
- (void)show;                                       // 显示进度视图 (带动画)
- (void)dismiss;                                    // 隐藏进度视图 (带动画)
@end

@implementation DYYYDownloadProgressView

// 初始化视图控件
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor]; // 背景透明
        self.isCancelled = NO; // 初始未取消

        // 设置容器视图 (居中、深色、圆角)
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 140)];
        _containerView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        _containerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95]; // 深灰色半透明
        _containerView.layer.cornerRadius = 12;
        _containerView.clipsToBounds = YES; // 超出部分裁剪
        [self addSubview:_containerView];

        // 设置进度条背景 (灰色圆角条)
        _progressBarBackground = [[UIView alloc] initWithFrame:CGRectMake(20, 50, CGRectGetWidth(_containerView.frame) - 40, 8)];
        _progressBarBackground.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0]; // 稍浅灰色
        _progressBarBackground.layer.cornerRadius = 4;
        [_containerView addSubview:_progressBarBackground];

        // 设置进度条 (蓝色圆角条，初始宽度为0)
        _progressBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGRectGetHeight(_progressBarBackground.frame))];
        _progressBar.backgroundColor = [UIColor colorWithRed:0.0 green:0.7 blue:1.0 alpha:1.0]; // 蓝色
        _progressBar.layer.cornerRadius = 4;
        [_progressBarBackground addSubview:_progressBar]; // 加到背景条上

        // 设置进度文字 (居中、白色)
        _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_progressBarBackground.frame) + 12, CGRectGetWidth(_containerView.frame), 20)];
        _progressLabel.textAlignment = NSTextAlignmentCenter;
        _progressLabel.textColor = [UIColor whiteColor];
        _progressLabel.font = [UIFont systemFontOfSize:14];
        _progressLabel.text = @"0%"; // 初始显示0%
        [_containerView addSubview:_progressLabel];

        // 设置取消按钮 (居中、深灰色背景、白色文字、圆角)
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _cancelButton.frame = CGRectMake((CGRectGetWidth(_containerView.frame) - 80) / 2, CGRectGetMaxY(_progressLabel.frame) + 18, 80, 32);
        _cancelButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; // 更深的灰色
        [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        [_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _cancelButton.layer.cornerRadius = 16;
        [_cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside]; // 添加点击事件
        [_containerView addSubview:_cancelButton];

        // 设置标题 (居中、白色、加粗)
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, CGRectGetWidth(_containerView.frame), 20)];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        titleLabel.text = @"正在下载";
        [_containerView addSubview:titleLabel];

        self.alpha = 0; // 初始透明，用于动画显示
    }
    return self;
}

// 设置进度 (更新进度条宽度和百分比文字)
- (void)setProgress:(float)progress {
    // 确保在主线程更新 UI
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setProgress:progress];
        });
        return;
    }
    progress = MAX(0.0, MIN(1.0, progress)); // 保证进度在 0.0 到 1.0 之间
    CGRect progressFrame = _progressBar.frame;
    progressFrame.size.width = progress * CGRectGetWidth(_progressBarBackground.frame); // 计算进度条宽度
    _progressBar.frame = progressFrame;
    int percentage = (int)(progress * 100); // 计算百分比整数
    _progressLabel.text = [NSString stringWithFormat:@"%d%%", percentage]; // 更新文字
}

// 显示视图 (添加到 KeyWindow 并渐显)
- (void)show {
    UIWindow *window = [DYYYManager getActiveWindow];
    if (!window) return;
    [window addSubview:self];
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1.0; // 渐显动画
    }];
}

// 隐藏视图 (渐隐并从父视图移除)
- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0; // 渐隐动画
    } completion:^(BOOL finished) {
        [self removeFromSuperview]; // 动画完成后移除
    }];
}

// 取消按钮点击处理
- (void)cancelButtonTapped {
    self.isCancelled = YES; // 标记为已取消
    if (self.cancelBlock) {
        self.cancelBlock(); // 调用取消回调
    }
    [self dismiss]; // 隐藏视图
}

@end


// 下载管理类（私有接口扩展）
@interface DYYYManager () <NSURLSessionDownloadDelegate> // 遵循下载代理协议
// --- 下载管理属性 ---
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *downloadTasks;         // 下载任务字典 (key: downloadID, value: NSURLSessionDownloadTask)
@property (nonatomic, strong) NSMutableDictionary<NSString *, DYYYDownloadProgressView *> *progressViews;        // 进度视图字典 (key: downloadID 或 batchID, value: DYYYDownloadProgressView)
@property (nonatomic, strong) NSOperationQueue *downloadQueue;                                                  // 下载队列 (可能用于控制并发，但当前实现未使用 NSOperation)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *taskProgressMap;                     // 单任务进度字典 (key: downloadID, value: NSNumber<float>)
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(BOOL success, NSURL *fileURL)> *completionBlocks; // 单任务完成回调字典 (key: downloadID, value: 回调 Block)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *mediaTypeMap;                        // 媒体类型字典 (key: downloadID, value: NSNumber<MediaType>)
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(float)> *taskProgressBlocks;             // 单任务进度回调字典 (key: downloadID, value: 回调 Block)

// --- 批量下载管理属性 ---
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *downloadToBatchMap;                  // 下载ID到批量ID的映射 (key: downloadID, value: batchID)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchCompletedCountMap;              // 批量任务已完成计数 (key: batchID, value: NSNumber<NSInteger>)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchSuccessCountMap;               // 批量任务成功计数 (key: batchID, value: NSNumber<NSInteger>)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *batchTotalCountMap;                 // 批量任务总数 (key: batchID, value: NSNumber<NSInteger>)
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(NSInteger current, NSInteger total)> *batchProgressBlocks; // 批量任务进度回调 (key: batchID, value: 回调 Block)
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(NSInteger successCount, NSInteger totalCount)> *batchCompletionBlocks; // 批量任务完成回调 (key: batchID, value: 回调 Block)
@end


@implementation DYYYManager

// 获取单例实例
+ (instancetype)shared {
    static DYYYManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ // 只执行一次
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

// 初始化方法
- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化所有字典和队列
        _fileLinks = [NSMutableDictionary dictionary]; // Live Photo 路径缓存 (公开属性)
        _downloadTasks = [NSMutableDictionary dictionary];
        _progressViews = [NSMutableDictionary dictionary];
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 3; // 设置最大并发下载数为 3 (但当前下载没用 Operation)
        _taskProgressMap = [NSMutableDictionary dictionary];
        _completionBlocks = [NSMutableDictionary dictionary];
        _mediaTypeMap = [NSMutableDictionary dictionary];
        _taskProgressBlocks = [NSMutableDictionary dictionary];

        _downloadToBatchMap = [NSMutableDictionary dictionary];
        _batchCompletedCountMap = [NSMutableDictionary dictionary];
        _batchSuccessCountMap = [NSMutableDictionary dictionary];
        _batchTotalCountMap = [NSMutableDictionary dictionary];
        _batchProgressBlocks = [NSMutableDictionary dictionary];
        _batchCompletionBlocks = [NSMutableDictionary dictionary];
    }
    return self;
}

// 首先添加 NSURLSessionDownloadDelegate 方法实现
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)localURL {
    // 处理下载完成
    NSString *downloadID = [[downloadTask originalRequest].URL absoluteString];
    void (^completionBlock)(BOOL, NSURL *) = _completionBlocks[downloadID];
    
    if(completionBlock) {
        completionBlock(YES, localURL);
    }
}

// 下载进度更新
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask 
                                           didWriteData:(int64_t)bytesWritten 
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // 计算下载进度
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    NSString *downloadID = [[downloadTask originalRequest].URL absoluteString];
    
    // 更新任务进度map
    [self.taskProgressMap setObject:@(progress) forKey:downloadID];
    
    // 如果有进度回调，调用它
    void (^progressBlock)(float) = [self.taskProgressBlocks objectForKey:downloadID];
    if (progressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressBlock(progress);
        });
    }
    
    // 如果有进度视图，更新它
    DYYYDownloadProgressView *progressView = [self.progressViews objectForKey:downloadID];
    if (progressView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressView setProgress:progress];
        });
    }
    
    // 处理批量下载的情况
    NSString *batchID = self.downloadToBatchMap[downloadID];
    if (batchID) {
        // 更新批量下载的整体进度...
        // 这部分代码可以根据需要实现
    }
}

// 下载完成时
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSString *downloadID = [[task originalRequest].URL absoluteString];
    
    // 获取完成回调
    void (^completionBlock)(BOOL, NSURL *) = [self.completionBlocks objectForKey:downloadID];
    
    // 如果有错误且不是因为用户取消，则回调失败
    if (error && error.code != NSURLErrorCancelled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 隐藏进度视图
            DYYYDownloadProgressView *progressView = [self.progressViews objectForKey:downloadID];
            if (progressView) {
                [progressView dismiss];
                [self.progressViews removeObjectForKey:downloadID];
            }
            
            // 调用回调
            if (completionBlock) {
                completionBlock(NO, nil);
            }
            
            [DYYYManager showToast:@"下载失败"];
        });
    }
    
    // 清理资源
    [self.downloadTasks removeObjectForKey:downloadID];
    [self.completionBlocks removeObjectForKey:downloadID];
    [self.taskProgressBlocks removeObjectForKey:downloadID];
    [self.mediaTypeMap removeObjectForKey:downloadID];
    
    // 处理批量下载的情况
    NSString *batchID = [self.downloadToBatchMap objectForKey:downloadID];
    if (batchID) {
        [self.downloadToBatchMap removeObjectForKey:downloadID];
        // 更新批量下载状态...
    }
}

// 添加 saveLivePhoto 实现
- (void)saveLivePhoto:(NSString *)imageSourcePath videoUrl:(NSString *)videoSourcePath {
    PHPhotoLibrary *photoLibrary = [PHPhotoLibrary sharedPhotoLibrary];
    
    // 先检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:imageSourcePath] || ![fileManager fileExistsAtPath:videoSourcePath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYManager showToast:@"Live Photo文件异常，无法保存"];
        });
        return;
    }
    
    // 检查权限
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYManager showToast:@"需要相册权限才能保存Live Photo"];
            });
            return;
        }
        
        // 创建和保存Live Photo
        [photoLibrary performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
            options.shouldMoveFile = NO; // 让系统复制而不是移动文件
            
            // 先添加视频资源，再添加图片资源
            [request addResourceWithType:PHAssetResourceTypePairedVideo 
                            fileURL:[NSURL fileURLWithPath:videoSourcePath] 
                            options:options];
            [request addResourceWithType:PHAssetResourceTypePhoto 
                            fileURL:[NSURL fileURLWithPath:imageSourcePath] 
                            options:options];
            
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [DYYYManager showToast:@"Live Photo已保存到相册"];
                } else {
                    NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                    [DYYYManager showToast:[NSString stringWithFormat:@"保存Live Photo失败: %@", errorMsg]];
                }
            });
        }];
    }];
}

// 添加下载 Live Photo 的类方法实现
+ (void)downloadLivePhoto:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(void))completion {
    [self downloadAndSaveLivePhotoWithImageURL:imageURL videoURL:videoURL completion:^(BOOL success, NSError *error) {
        if (completion) {
            completion();
        }
    }];
}

// 添加批量下载 Live Photos 方法实现 
+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos {
    [self downloadAllLivePhotosWithProgress:livePhotos progress:nil completion:nil];
}

// 添加带进度的批量下载 Live Photos 实现
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos 
                                progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                              completion:(void (^)(NSInteger successCount, NSInteger totalCount))completionBlock {
    NSInteger totalCount = livePhotos.count;
    __block NSInteger completedCount = 0;
    __block NSInteger successCount = 0;
    
    for (NSDictionary *livePhoto in livePhotos) {
        NSURL *imageURL = [NSURL URLWithString:livePhoto[@"imageURL"]];
        NSURL *videoURL = [NSURL URLWithString:livePhoto[@"videoURL"]];
        
        [self downloadLivePhoto:imageURL videoURL:videoURL completion:^{
            completedCount++;
            successCount++;
            
            if (progressBlock) {
                progressBlock(completedCount, totalCount);
            }
            
            if (completedCount == totalCount && completionBlock) {
                completionBlock(successCount, totalCount);
            }
        }];
    }
}

// 添加普通下载方法实现
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    [self downloadMediaWithProgress:url mediaType:mediaType progress:nil completion:^(BOOL success, NSURL *fileURL) {
        if (completion) {
            completion();
        }
    }];
}

// 修改downloadMediaWithProgress方法
+ (void)downloadMediaWithProgress:(NSURL *)url mediaType:(MediaType)mediaType 
                       progress:(void (^)(float))progressBlock 
                     completion:(void (^)(BOOL, NSURL *))completionBlock {
    if (!url) {
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(NO, nil);
            });
        }
        return;
    }
    
    // 如果未指定媒体类型，尝试自动检测
    if (mediaType == MediaTypeUnknown) {
        mediaType = [self intelligentDetectMediaType:url];
    }
    
    NSString *downloadID = [url absoluteString];
    
    // 如果有进度回调，存储它
    if (progressBlock) {
        [[DYYYManager shared].taskProgressBlocks setObject:progressBlock forKey:downloadID];
    }
    
    // 显示进度视图（如果需要）
    if (progressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYDownloadProgressView *progressView = [[DYYYDownloadProgressView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            progressView.cancelBlock = ^{
                // 取消下载任务
                NSURLSessionDownloadTask *task = [[DYYYManager shared].downloadTasks objectForKey:downloadID];
                if (task) {
                    [task cancel];
                }
            };
            [[DYYYManager shared].progressViews setObject:progressView forKey:downloadID];
            [progressView show];
        });
    }
    
    // 记录媒体类型
    [[DYYYManager shared].mediaTypeMap setObject:@(mediaType) forKey:downloadID];
    
    // 创建下载会话配置
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0; // 增加超时时间到30秒
    config.timeoutIntervalForResource = 60.0; // 资源超时时间
    config.HTTPMaximumConnectionsPerHost = 10; // 增加连接数
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:[DYYYManager shared] delegateQueue:nil];
    
    // 创建下载任务
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
    task.priority = NSURLSessionTaskPriorityHigh; // 设置高优先级
    
    [[DYYYManager shared].downloadTasks setObject:task forKey:downloadID];
    [[DYYYManager shared].completionBlocks setObject:completionBlock forKey:downloadID];
    
    [task resume];
}

// 添加取消所有下载的实现
+ (void)cancelAllDownloads {
    for (NSURLSessionDownloadTask *task in [DYYYManager shared].downloadTasks.allValues) {
        [task cancel];
    }
    [[DYYYManager shared].downloadTasks removeAllObjects];
    [[DYYYManager shared].completionBlocks removeAllObjects];
    [[DYYYManager shared].taskProgressBlocks removeAllObjects];
}

// 添加带进度的批量下载图片实现
+ (void)downloadAllImagesWithProgress:(NSArray<NSString *> *)imageURLs 
                           progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                         completion:(void (^)(NSInteger successCount, NSInteger totalCount))completionBlock {
    NSInteger totalCount = imageURLs.count;
    __block NSInteger completedCount = 0;
    __block NSInteger successCount = 0;
    
    for (NSString *urlString in imageURLs) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            completedCount++;
            if (progressBlock) {
                progressBlock(completedCount, totalCount);
            }
            continue;
        }
        
        [self downloadMediaWithProgress:url mediaType:MediaTypeImage progress:^(float progress) {
            // 单个下载的进度我们不传递出去
        } completion:^(BOOL success, NSURL *fileURL) {
            completedCount++;
            if (success) successCount++;
            
            if (progressBlock) {
                progressBlock(completedCount, totalCount);
            }
            
            if (completedCount == totalCount && completionBlock) {
                completionBlock(successCount, totalCount);
            }
        }];
    }
}

+ (void)downloadAllImages:(NSArray<NSString *> *)imageURLs {
    [self downloadAllImagesWithProgress:imageURLs progress:nil completion:nil];
}

// 添加图片转视频功能完整实现
+ (void)convertImagesToVideo:(NSArray<NSString *> *)imageURLStrings completion:(void (^)(NSURL *videoURL))completion {
    // 检查URL有效性
    if (!imageURLStrings || imageURLStrings.count == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"没有有效的图片可合成"];
                completion(nil);
            });
        }
        return;
    }
    
    NSMutableArray *imageURLs = [NSMutableArray array];
    for (NSString *urlString in imageURLStrings) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (url) [imageURLs addObject:url];
    }
    
    if (imageURLs.count == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"未找到有效图片"];
                completion(nil);
            });
        }
        return;
    }
    
    // 创建进度视图
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYDownloadProgressView *progressView = [[DYYYDownloadProgressView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [progressView show];
        progressView.progressLabel.text = @"准备合成视频...";
        
        // 获取配置参数
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        float frameRate = [defaults floatForKey:@"DYYYVideoFrameRate"];
        if (frameRate <= 0) frameRate = 30.0f; // 默认30fps
        
        float duration = [defaults floatForKey:@"DYYYVideoDuration"];
        if (duration <= 0) duration = 3.0f;     // 默认3秒
        
        // 创建临时视频输出路径
        NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"combined_video_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]]];
        NSURL *outputURL = [NSURL fileURLWithPath:tempFilePath];
        
        // 下载所有图片然后开始处理
        [self downloadAllImageURLsForVideo:imageURLs progress:^(float progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:progress * 0.5]; // 下载占50%进度
                progressView.progressLabel.text = [NSString stringWithFormat:@"下载图片...%d%%", (int)(progress * 100)];
            });
        } completion:^(NSArray<NSURL *> *localImageURLs) {
            if (localImageURLs.count > 0) {
                // 确定视频大小 - 根据第一张图片，但最大支持4K
                CGSize videoSize = [self getOptimalVideoSizeFromImages:localImageURLs];
                
                // 创建视频写入器
                AVAssetWriter *writer = [self createAssetWriterWithURL:outputURL size:videoSize frameRate:frameRate];
                if (!writer) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [progressView dismiss];
                        [self showToast:@"创建视频失败，请再试一次"];
                        if (completion) completion(nil);
                    });
                    return;
                }
                
                // 开始合成视频
                [self processVideoSynthesis:writer 
                                 imageURLs:localImageURLs 
                                 frameRate:frameRate 
                                  duration:duration 
                                targetSize:videoSize 
                              progressView:progressView 
                                completion:^(BOOL success, NSError *error) {
                    // 清理临时图片文件
                    for (NSURL *imageURL in localImageURLs) {
                        [[NSFileManager defaultManager] removeItemAtURL:imageURL error:nil];
                    }
                    
                    if (success) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [progressView dismiss];
                            [self showToast:@"视频已合成，正在保存..."];
                            if (completion) completion(outputURL);
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [progressView dismiss];
                            NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                            [self showToast:[NSString stringWithFormat:@"视频合成失败: %@", errorMsg]];
                            if (completion) completion(nil);
                        });
                        [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
                    }
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [progressView dismiss];
                    [self showToast:@"没有有效图片可合成"];
                    if (completion) completion(nil);
                });
            }
        }];
    });
}

// 下载所有图片用于视频合成
+ (void)downloadAllImageURLsForVideo:(NSArray<NSURL *> *)imageURLs 
                           progress:(void (^)(float))progressBlock
                         completion:(void (^)(NSArray<NSURL *> *localImageURLs))completion {
    NSInteger totalCount = imageURLs.count;
    __block NSInteger completedCount = 0;
    __block NSMutableArray *localImageURLs = [NSMutableArray array];
    
    for (NSURL *imageURL in imageURLs) {
        [self downloadMediaWithProgress:imageURL mediaType:MediaTypeImage progress:nil completion:^(BOOL success, NSURL *fileURL) {
            if (success && fileURL) {
                // 复制到临时目录以避免自动删除
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                     [NSString stringWithFormat:@"img_%ld_%@", (long)completedCount, [NSUUID UUID].UUIDString]];
                NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
                
                NSError *error = nil;
                if ([[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:tempURL error:&error]) {
                    [localImageURLs addObject:tempURL];
                }
                
                // 删除原下载文件
                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            }
            
            completedCount++;
            if (progressBlock) {
                progressBlock((float)completedCount / totalCount);
            }
            
            if (completedCount == totalCount) {
                if (completion) completion(localImageURLs);
            }
        }];
    }
}

// 创建视频写入器并添加帧率参数
+ (AVAssetWriter *)createAssetWriterWithURL:(NSURL *)outputURL size:(CGSize)size frameRate:(float)frameRate {
    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        NSLog(@"创建AVAssetWriter失败: %@", error);
        return nil;
    }
    
    // 使用更高质量的视频编码设置
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(8000000), // 8 Mbps
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
            AVVideoMaxKeyFrameIntervalKey: @(frameRate * 2), // 2秒一个关键帧
            AVVideoExpectedSourceFrameRateKey: @(frameRate)
        }
    };
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    writerInput.expectsMediaDataInRealTime = NO;
    [writer addInput:writerInput];
    
    return writer;
}

// 优化视频合成过程处理
+ (void)processVideoSynthesis:(AVAssetWriter *)writer
                   imageURLs:(NSArray<NSURL *> *)imageURLs
                  frameRate:(CGFloat)frameRate
                  duration:(CGFloat)totalDuration
                targetSize:(CGSize)targetSize
               progressView:(DYYYDownloadProgressView *)progressView
                completion:(void (^)(BOOL success, NSError *error))completion {
    // 设置写入参数
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(targetSize.width),
        AVVideoHeightKey: @(targetSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(8000000), // 8 Mbps 高质量
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
            AVVideoMaxKeyFrameIntervalKey: @(frameRate * 2), // 2秒一个关键帧
            AVVideoExpectedSourceFrameRateKey: @(frameRate)
        }
    };
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    writerInput.expectsMediaDataInRealTime = NO;
    
    NSDictionary *sourcePixelBufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (NSString *)kCVPixelBufferWidthKey: @(targetSize.width),
        (NSString *)kCVPixelBufferHeightKey: @(targetSize.height),
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributes];
    
    [writer addInput:writerInput];
    
    if (![writer startWriting]) {
        if (completion) completion(NO, writer.error);
        return;
    }
    
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    // 计算每张图片持续时间和总帧数
    NSInteger totalFrameCount = (NSInteger)(frameRate * totalDuration);
    NSInteger framesPerImage = totalFrameCount / imageURLs.count;
    if (framesPerImage < 1) framesPerImage = 1;
    
    dispatch_queue_t processingQueue = dispatch_queue_create("com.dyyy.videosynthesis", DISPATCH_QUEUE_SERIAL);
    
    __block BOOL success = YES;
    __block NSError *processingError = nil;
    
    dispatch_async(processingQueue, ^{
        // 预先加载所有图片以提高性能
        NSMutableArray<UIImage *> *loadedImages = [NSMutableArray arrayWithCapacity:imageURLs.count];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            progressView.progressLabel.text = @"加载图片...";
        });
        
        for (NSInteger i = 0; i < imageURLs.count; i++) {
            NSURL *imageURL = imageURLs[i];
            UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
            
            if (image) {
                [loadedImages addObject:image];
            } else {
                NSLog(@"无法加载图片: %@", imageURL);
            }
            
            // 更新加载进度
            CGFloat loadProgress = 0.5 + ((CGFloat)i / imageURLs.count) * 0.25;
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:loadProgress];
            });
        }
        
        if (loadedImages.count == 0) {
            success = NO;
            processingError = [NSError errorWithDomain:@"DYYYError" code:-3 
                                             userInfo:@{NSLocalizedDescriptionKey: @"无法加载任何图片"}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [writer cancelWriting];
                if (completion) completion(NO, processingError);
            });
            return;
        }
        
        // 开始合成视频
        dispatch_async(dispatch_get_main_queue(), ^{
            progressView.progressLabel.text = @"合成视频中...";
        });
        
        CVPixelBufferRef pixelBuffer = NULL;
        CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pixelBuffer);
        
        if (pixelBuffer == NULL) {
            CVPixelBufferCreate(kCFAllocatorDefault,
                               targetSize.width,
                               targetSize.height,
                               kCVPixelFormatType_32ARGB,
                               (__bridge CFDictionaryRef)sourcePixelBufferAttributes,
                               &pixelBuffer);
        }
        
        if (pixelBuffer == NULL) {
            success = NO;
            processingError = [NSError errorWithDomain:@"DYYYError" code:-4 
                                             userInfo:@{NSLocalizedDescriptionKey: @"无法创建像素缓冲区"}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [writer cancelWriting];
                if (completion) completion(NO, processingError);
            });
            return;
        }
        
        NSInteger frameIndex = 0;
        NSInteger totalFrames = framesPerImage * loadedImages.count;
        
        for (NSInteger i = 0; i < loadedImages.count && success; i++) {
            UIImage *image = loadedImages[i];
            
            // 调整图片适应目标尺寸
            UIImage *resizedImage = [self resizeImage:image toSize:targetSize];
            
            // 绘制图片到像素缓冲区
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            
            void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(data,
                                                        targetSize.width,
                                                        targetSize.height,
                                                        8,
                                                        CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                        colorSpace,
                                                        kCGImageAlphaPremultipliedFirst);
            
            if (context) {
                // 填充黑色背景
                CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
                CGContextFillRect(context, CGRectMake(0, 0, targetSize.width, targetSize.height));
                
                // 居中绘制图片
                CGRect drawRect = [self centeredRectForImage:resizedImage inSize:targetSize];
                CGContextDrawImage(context, drawRect, resizedImage.CGImage);
                
                CGContextRelease(context);
            }
            
            CGColorSpaceRelease(colorSpace);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            
            // 为当前图片添加多个帧
            for (NSInteger f = 0; f < framesPerImage && success; f++) {
                // 如果writer已停止或输入不接受更多数据，中断处理
                if (writer.status != AVAssetWriterStatusWriting || !writerInput.readyForMoreMediaData) {
                    success = NO;
                    processingError = writer.error ?: [NSError errorWithDomain:@"DYYYError" code:-5 
                                                               userInfo:@{NSLocalizedDescriptionKey: @"视频写入中断"}];
                    break;
                }
                
                CMTime presentationTime = CMTimeMake(frameIndex, frameRate);
                
                if (![adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime]) {
                    success = NO;
                    processingError = writer.error ?: [NSError errorWithDomain:@"DYYYError" code:-6 
                                                               userInfo:@{NSLocalizedDescriptionKey: @"无法添加帧到视频"}];
                    break;
                }
                
                frameIndex++;
                
                // 更新合成进度
                CGFloat synthProgress = 0.75 + ((CGFloat)frameIndex / totalFrames) * 0.25;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [progressView setProgress:synthProgress];
                    progressView.progressLabel.text = [NSString stringWithFormat:@"合成视频...%d%%", 
                                                      (int)(((CGFloat)frameIndex / totalFrames) * 100)];
                });
            }
        }
        
        if (pixelBuffer) {
            CVPixelBufferRelease(pixelBuffer);
        }
        
        // 结束视频写入
        if (success) {
            [writerInput markAsFinished];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                progressView.progressLabel.text = @"完成视频写入...";
                [progressView setProgress:1.0];
            });
            
            [writer finishWritingWithCompletionHandler:^{
                if (writer.status == AVAssetWriterStatusCompleted) {
                    if (completion) completion(YES, nil);
                } else {
                    if (completion) completion(NO, writer.error);
                }
            }];
        } else {
            [writer cancelWriting];
            if (completion) completion(NO, processingError);
        }
    });
}

// 添加计算图片在视频中居中位置的方法
+ (CGRect)centeredRectForImage:(UIImage *)image inSize:(CGSize)size {
    CGFloat scale = MIN(size.width / image.size.width, size.height / image.size.height);
    CGSize scaledSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    
    CGFloat x = (size.width - scaledSize.width) / 2.0;
    CGFloat y = (size.height - scaledSize.height) / 2.0;
    
    return CGRectMake(x, y, scaledSize.width, scaledSize.height);
}

// 增强HEIC到GIF转换功能
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    if (!heicURL) {
        if (completion) completion(nil, NO);
        return;
    }

    // 生成GIF文件名和临时路径
    NSString *gifFileName = [[heicURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
    NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];

    NSData *heicData = [NSData dataWithContentsOfURL:heicURL];
    if (!heicData) {
        if (completion) completion(nil, NO);
        return;
    }

    // 在后台队列执行转换
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageSourceRef heicSource = CGImageSourceCreateWithData((__bridge CFDataRef)heicData, NULL);
        if (!heicSource) {
            dispatch_async(dispatch_get_main_queue(), ^{ 
                if (completion) completion(nil, NO); 
            });
            return;
        }

        size_t count = CGImageSourceGetCount(heicSource);
        if (count == 0) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{ 
                if (completion) completion(nil, NO); 
            });
            return;
        }

        // 使用新的UTType API
        NSString *gifUTI = nil;
        if (@available(iOS 15.0, *)) {
            // 使用正确的API导入UniformTypeIdentifiers
            gifUTI = UTTypeGIF.identifier;
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            gifUTI = (__bridge NSString *)kUTTypeGIF;
#pragma clang diagnostic pop
        }

        // 创建GIF目标
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)gifURL,
            (__bridge CFStringRef)gifUTI,
            count,
            NULL
        );
        
        if (!destination) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{ 
                if (completion) completion(nil, NO); 
            });
            return;
        }

        // GIF配置
        NSDictionary *gifProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0,  // 无限循环
                (__bridge NSString *)kCGImagePropertyColorModel: @"RGB" // 确保颜色正确
            }
        };
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);

        BOOL allFramesAdded = YES;
        
        // 获取所有帧的延迟时间信息
        NSMutableArray *frameDelays = [NSMutableArray arrayWithCapacity:count];

        for (size_t i = 0; i < count; i++) {
            CFDictionaryRef frameProperties = CGImageSourceCopyPropertiesAtIndex(heicSource, i, NULL);
            if (frameProperties) {
                CFDictionaryRef heicDict = NULL;
                if (CFDictionaryContainsKey(frameProperties, kCGImagePropertyHEICSDictionary)) {
                    heicDict = (CFDictionaryRef)CFDictionaryGetValue(frameProperties, kCGImagePropertyHEICSDictionary);
                }
                
                if (heicDict) {
                    CFNumberRef delayTimeRef = NULL;
                    if (CFDictionaryContainsKey(heicDict, kCGImagePropertyHEICSDDelayTime)) {
                        delayTimeRef = (CFNumberRef)CFDictionaryGetValue(heicDict, kCGImagePropertyHEICSDDelayTime);
                    }
                    
                    if (delayTimeRef) {
                        float delayTime = 0;
                        CFNumberGetValue(delayTimeRef, kCFNumberFloatType, &delayTime);
                        [frameDelays addObject:@(delayTime)];
                    }
                }
                CFRelease(frameProperties);
            }
        }
        
        // 如果没有检测到任何延迟时间，设置默认值
        if (frameDelays.count == 0) {
            float defaultDelay = 0.1; // 默认每帧0.1秒
            for (size_t i = 0; i < count; i++) {
                [frameDelays addObject:@(defaultDelay)];
            }
        }
        
        // 遍历HEIC的每一帧
        for (size_t i = 0; i < count; i++) {
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, i, NULL);
            if (!imageRef) {
                allFramesAdded = NO;
                continue;
            }

            // 设置帧属性
            NSMutableDictionary *frameProps = [NSMutableDictionary dictionary];
            NSMutableDictionary *gifDict = [NSMutableDictionary dictionary];
            
            // 使用检测到的延迟时间或默认值
            CGFloat delayTime = i < frameDelays.count ? [frameDelays[i] floatValue] : 0.1;
            gifDict[@"DelayTime"] = @(delayTime);
            gifDict[@"DisposalMethod"] = @2; // 替换前一帧
            
            frameProps[(__bridge NSString *)kCGImagePropertyGIFDictionary] = gifDict;

            // 添加帧到GIF
            CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProps);
            CGImageRelease(imageRef);
        }

        // 完成GIF写入
        BOOL success = allFramesAdded && CGImageDestinationFinalize(destination);
        CFRelease(heicSource);
        CFRelease(destination);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (completion) completion(gifURL, YES);
            } else {
                if (completion) completion(nil, NO);
            }
        });
    });
}

// 增强全面的媒体格式识别
+ (MediaType)intelligentDetectMediaType:(NSURL *)url {
    // 1. 扩展名识别
    NSString *pathExtension = url.pathExtension.lowercaseString;
    
    // 视频格式 (扩展更多格式)
    NSSet *videoExtensions = [NSSet setWithArray:@[
        // 常见视频格式
        @"mp4", @"mov", @"m4v", @"3gp", @"avi", @"mkv", @"wmv", @"flv", @"webm",
        // 专业视频格式
        @"mxf", @"vob", @"m2ts", @"ts", @"mts", @"mpg", @"mpeg", @"m2v",
        // 新兴视频格式
        @"hevc", @"x265", @"x264", @"264", @"265"
    ]];
    
    // 图片格式 (扩展更多格式)
    NSSet *imageExtensions = [NSSet setWithArray:@[
        // 常见图片格式
        @"jpg", @"jpeg", @"png", @"gif", @"webp", @"heic", @"heif",
        // 专业图片格式
        @"raw", @"cr2", @"nef", @"arw", @"dng", @"raf", @"tiff", @"tif",
        // 其他图片格式
        @"bmp", @"ico", @"svg", @"psd", @"ai", @"eps"
    ]];
    
    // 音频格式 (扩展更多格式)
    NSSet *audioExtensions = [NSSet setWithArray:@[
        // 常见音频格式
        @"mp3", @"wav", @"aac", @"m4a", @"wma", @"ogg", @"flac", @"alac",
        // 专业音频格式
        @"aiff", @"aif", @"pcm", @"dsd", @"dsf", @"dff",
        // 其他音频格式
        @"ape", @"mka", @"opus", @"ac3", @"dts", @"mid", @"midi"
    ]];

    // 2. MIME 类型映射
    NSDictionary *mimeTypeMap = @{
        // 视频 MIME 类型
        @"video/mp4": @(MediaTypeVideo),
        @"video/quicktime": @(MediaTypeVideo),
        @"video/x-msvideo": @(MediaTypeVideo),
        @"video/x-matroska": @(MediaTypeVideo),
        @"video/webm": @(MediaTypeVideo),
        @"video/x-flv": @(MediaTypeVideo),
        @"application/x-mpegURL": @(MediaTypeVideo),
        
        // 图片 MIME 类型
        @"image/jpeg": @(MediaTypeImage),
        @"image/png": @(MediaTypeImage),
        @"image/gif": @(MediaTypeGIF),
        @"image/webp": @(MediaTypeImage),
        @"image/heic": @(MediaTypeHeic),
        @"image/heif": @(MediaTypeHeic),
        @"image/tiff": @(MediaTypeImage),
        @"image/bmp": @(MediaTypeImage),
        @"image/x-adobe-dng": @(MediaTypeImage),
        
        // 音频 MIME 类型
        @"audio/mpeg": @(MediaTypeAudio),
        @"audio/wav": @(MediaTypeAudio),
        @"audio/x-wav": @(MediaTypeAudio),
        @"audio/aac": @(MediaTypeAudio),
        @"audio/mp4": @(MediaTypeAudio),
        @"audio/ogg": @(MediaTypeAudio),
        @"audio/flac": @(MediaTypeAudio),
        @"audio/x-ms-wma": @(MediaTypeAudio)
    };

    // 3. 基于扩展名的初步判断
    if ([videoExtensions containsObject:pathExtension]) {
        return MediaTypeVideo;
    } else if ([imageExtensions containsObject:pathExtension]) {
        return [self analyzeImageType:url];
    } else if ([audioExtensions containsObject:pathExtension]) {
        return MediaTypeAudio;
    }

    // 4. 深度分析文件内容和 HTTP 头
    return [self deepAnalyzeMediaType:url withMimeMap:mimeTypeMap];
}

// 深度分析媒体类型
+ (MediaType)deepAnalyzeMediaType:(NSURL *)url withMimeMap:(NSDictionary *)mimeTypeMap {
    __block MediaType detectedType = MediaTypeUnknown;
    
    // 1. 尝试从文件头部分析 (Magic Numbers)
    if ([url isFileURL]) {
        NSError *error = nil;
        NSData *headerData = [NSData dataWithContentsOfURL:url 
                                                   options:NSDataReadingMappedIfSafe|NSDataReadingUncached 
                                                     error:&error];
        if (headerData && headerData.length > 16) {
            NSData *header = [headerData subdataWithRange:NSMakeRange(0, MIN(headerData.length, 16))];
            const uint8_t *bytes = (const uint8_t *)[header bytes];
            
            // JPEG 检查
            if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
                return MediaTypeImage;
            }
            // PNG 检查
            else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
                return MediaTypeImage;
            }
            // GIF 检查
            else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
                return MediaTypeGIF;
            }
            // MP4 检查 (ftyp)
            else if (headerData.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
                return MediaTypeVideo;
            }
            // WEBP 检查
            else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
                     bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
                return MediaTypeImage;
            }
            // MP3 检查
            else if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) || // ID3v2
                     (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) { // MPEG
                return MediaTypeAudio;
            }
            // HEIC检查 (ftyp...)
            else if (headerData.length >= 12 && 
                    ((bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 && 
                      bytes[8] == 0x68 && bytes[9] == 0x65 && bytes[10] == 0x69 && bytes[11] == 0x63) ||
                     (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 && 
                      bytes[8] == 0x68 && bytes[9] == 0x65 && bytes[10] == 0x69 && bytes[11] == 0x78))) {
                return MediaTypeHeic;
            }
        }
    }

    // 2. 从URL路径分析
    NSString *pathExtension = url.pathExtension.lowercaseString;
    if (pathExtension.length > 0) {
        // 视频扩展名检测 - 更新支持的格式
        NSSet *videoExtensions = [NSSet setWithArray:@[
            @"mp4", @"mov", @"m4v", @"3gp", @"avi", @"mkv", @"wmv", @"flv", @"webm",
            @"mxf", @"vob", @"m2ts", @"ts", @"mts", @"mpg", @"mpeg", @"m2v",
            @"hevc", @"x265", @"x264", @"264", @"265"
        ]];
        
        // 音频扩展名检测 - 更新支持的格式
        NSSet *audioExtensions = [NSSet setWithArray:@[
            @"mp3", @"wav", @"aac", @"m4a", @"wma", @"ogg", @"flac", @"alac",
            @"aiff", @"aif", @"pcm", @"dsd", @"dsf", @"dff",
            @"ape", @"mka", @"opus", @"ac3", @"dts", @"mid", @"midi"
        ]];
        
        // GIF专门检查
        if ([pathExtension isEqualToString:@"gif"]) {
            return MediaTypeGIF;
        }
        
        // HEIC/HEIF检查
        if ([pathExtension isEqualToString:@"heic"] || [pathExtension isEqualToString:@"heif"]) {
            return MediaTypeHeic;
        }
        
        // 其他扩展名检查
        if ([videoExtensions containsObject:pathExtension]) {
            return MediaTypeVideo;
        }
        
        if ([audioExtensions containsObject:pathExtension]) {
            return MediaTypeAudio;
        }
    }
    
    // 3. 基于URL查询参数的检测 (例如某些视频服务的URL模式)
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    if (components.query) {
        NSString *query = components.query.lowercaseString;
        if ([query containsString:@"video"] || [query containsString:@"mp4"] || 
            [query containsString:@"mov"] || [query containsString:@"media=video"]) {
            return MediaTypeVideo;
        }
        
        if ([query containsString:@"audio"] || [query containsString:@"mp3"] || 
            [query containsString:@"media=audio"]) {
            return MediaTypeAudio;
        }
        
        if ([query containsString:@"gif"] || [query containsString:@"type=gif"]) {
            return MediaTypeGIF;
        }
    }
    
    // 4. 从网络请求头分析，但不阻塞UI线程超过1秒
    if (![url isFileURL]) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"HEAD";
        request.timeoutInterval = 5.0; // 最多5秒超时
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSString *contentType = nil;
                
                if (@available(iOS 13.0, *)) {
                    contentType = [httpResponse valueForHTTPHeaderField:@"Content-Type"];
                } else {
                    // iOS 13 之前使用 allHeaderFields
                    NSDictionary *headers = [httpResponse allHeaderFields];
                    contentType = headers[@"Content-Type"];
                }
                
                if (contentType.length > 0) {
                    // 从 MIME 类型映射表查找
                    NSNumber *typeNumber = mimeTypeMap[contentType];
                    if (typeNumber) {
                        detectedType = (MediaType)[typeNumber integerValue];
                    }
                    // 处理特殊 MIME 类型
                    else if ([contentType containsString:@"video/"]) {
                        detectedType = MediaTypeVideo;
                    }
                    else if ([contentType containsString:@"image/"]) {
                        if ([contentType containsString:@"gif"]) {
                            detectedType = MediaTypeGIF;
                        } else if ([contentType containsString:@"heic"] || [contentType containsString:@"heif"]) {
                            detectedType = MediaTypeHeic;
                        } else {
                            detectedType = MediaTypeImage;
                        }
                    }
                    else if ([contentType containsString:@"audio/"]) {
                        detectedType = MediaTypeAudio;
                    }
                }
            }
            dispatch_semaphore_signal(semaphore);
        }];
        [task resume];
        
        // 等待网络请求完成，但最多等待1秒
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
    }
    
    return detectedType != MediaTypeUnknown ? detectedType : MediaTypeImage; // 默认返回图片类型
}

// 替换原有的 getActiveWindow 方法
+ (UIWindow *)getActiveWindow {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *scenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && 
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *windowInScene in windowScene.windows) {
                    if (windowInScene.isKeyWindow) {
                        window = windowInScene;
                        break;
                    }
                }
                if (window) break;
            }
        }
        if (!window && scenes.count > 0) {
            // 退化选择：如果找不到key window，使用任何可用的window
            for (UIScene *scene in scenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    if (windowScene.windows.count > 0) {
                        window = windowScene.windows.firstObject;
                        break;
                    }
                }
            }
        }
    } else {
        // iOS 13 之前的获取方法
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
    }
    
    return window;
}

// 获取顶层视图控制器 (用于 present 视图)
+ (UIViewController *)getActiveTopController {
    UIWindow *window = [self getActiveWindow]; // 获取窗口
    if (!window) return nil;
    UIViewController *topController = window.rootViewController; // 从根控制器开始
    while (topController.presentedViewController) { // 循环查找最上层的 presented 控制器
        topController = topController.presentedViewController;
    }
    return topController;
}

// 十六进制颜色字符串转 UIColor
+ (UIColor *)colorWithHexString:(NSString *)hexString {
    // 特殊处理: "random" 或 "#random" 返回随机颜色
    if ([[hexString lowercaseString] isEqualToString:@"random"] || [[hexString lowercaseString] isEqualToString:@"#random"]) {
        CGFloat red = arc4random_uniform(200) / 255.0; // 限制颜色范围，避免太亮
        CGFloat green = arc4random_uniform(200) / 255.0;
        CGFloat blue = arc4random_uniform(128) / 255.0; // 蓝色稍微限制多一点
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
    }

    NSString *colorString = hexString;
    if ([hexString hasPrefix:@"#"]) { // 去掉 # 前缀
        colorString = [hexString substringFromIndex:1];
    }

    // 处理 3 位缩写 (例如 "FFF" -> "FFFFFF")
    if (colorString.length == 3) {
        NSString *r = [colorString substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [colorString substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [colorString substringWithRange:NSMakeRange(2, 1)];
        colorString = [NSString stringWithFormat:@"%@%@%@%@%@%@", r, r, g, g, b, b];
    }

    // 处理 6 位 RGB (例如 "FF0000")
    if (colorString.length == 6) {
        unsigned int hexValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:colorString];
        [scanner scanHexInt:&hexValue]; // 扫描十六进制整数
        CGFloat red = ((hexValue & 0xFF0000) >> 16) / 255.0; // 提取 R 分量
        CGFloat green = ((hexValue & 0x00FF00) >> 8) / 255.0;  // 提取 G 分量
        CGFloat blue = (hexValue & 0x0000FF) / 255.0;         // 提取 B 分量
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0]; // Alpha 默认为 1.0
    }

    // 处理 8 位 RGBA (例如 "FF000080")
    if (colorString.length == 8) {
        unsigned int hexValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:colorString];
        [scanner scanHexInt:&hexValue];
        CGFloat red = ((hexValue & 0xFF000000) >> 24) / 255.0; // 提取 R 分量
        CGFloat green = ((hexValue & 0x00FF0000) >> 16) / 255.0; // 提取 G 分量
        CGFloat blue = ((hexValue & 0x0000FF00) >> 8) / 255.0;  // 提取 B 分量
        CGFloat alpha = (hexValue & 0x000000FF) / 255.0;       // 提取 Alpha 分量
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }

    return [UIColor whiteColor]; // 格式无效则返回白色
}

// 显示提示信息 (Toast) - 优先使用 DUXToast (如果存在)，否则用简单的 UILabel 实现
+ (void)showToast:(NSString *)text {
    Class toastClass = NSClassFromString(@"DUXToast"); // 尝试获取 DUXToast 类
    if (toastClass && [toastClass respondsToSelector:@selector(showText:)]) {
        // 如果 DUXToast 存在且响应 showText: 方法，则调用它
        [toastClass performSelector:@selector(showText:) withObject:text];
    } else {
        // 备用方案：使用 UILabel 实现简单的 Toast
        dispatch_async(dispatch_get_main_queue(), ^{ // 确保在主线程操作 UI
            UIWindow *window = [self getActiveWindow];
            if (!window) return;

            UILabel *toastLabel = [[UILabel alloc] init];
            toastLabel.text = text;
            toastLabel.font = [UIFont systemFontOfSize:14];
            toastLabel.textColor = [UIColor whiteColor];
            toastLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7]; // 半透明黑色背景
            toastLabel.textAlignment = NSTextAlignmentCenter;
            toastLabel.numberOfLines = 0; // 允许多行
            toastLabel.layer.cornerRadius = 8;
            toastLabel.clipsToBounds = YES;
            [toastLabel sizeToFit]; // 根据内容调整大小

            CGFloat padding = 10.0; // 内边距
            toastLabel.frame = CGRectMake(0, 0, toastLabel.frame.size.width + 2 * padding, toastLabel.frame.size.height + padding); // 调整 frame 加上内边距
            toastLabel.center = CGPointMake(window.center.x, window.bounds.size.height - 100); // 定位在屏幕底部

            [window addSubview:toastLabel];
            // 2 秒后渐隐并移除
            [UIView animateWithDuration:0.3 delay:2.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                toastLabel.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toastLabel removeFromSuperview];
            }];
        });
    }
}

// 保存媒体文件到相册 (处理 HEIC 转 GIF, 其他类型直接保存)
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (!mediaURL) { // URL 无效
        if (completion) completion();
        return;
    }

    // 请求相册权限
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) { // 已授权
            if (mediaType == MediaTypeHeic) { // 如果是 HEIC
                // 先转换成 GIF 再保存
                [self convertHeicToGif:mediaURL completion:^(NSURL *gifURL, BOOL success) {
                    if (success && gifURL) {
                        // 使用 PHPhotoLibrary 保存 GIF
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            NSData *gifData = [NSData dataWithContentsOfURL:gifURL];
                            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                            options.uniformTypeIdentifier = @"com.compuserve.gif"; // 指定类型为 GIF
                            [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{ // 回到主线程
                                if (success) {
                                    [self showToast:[NSString stringWithFormat:@"%@已保存到相册", [self getMediaTypeDescription:mediaType]]];
                                    if (completion) completion();
                                } else {
                                    [self showToast:@"保存失败"];
                                }
                            });
                            // 清理临时文件 (原始 HEIC 和转换后的 GIF)
                            [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:nil];
                            if (gifURL) [[NSFileManager defaultManager] removeItemAtURL:gifURL error:nil];
                        }];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showToast:@"转换失败"]; // HEIC 转 GIF 失败
                            if (completion) completion();
                        });
                        [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:nil]; // 清理原始 HEIC
                    }
                }];
            } else { // 非 HEIC 类型
                // 直接使用 PHPhotoLibrary 保存
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    if (mediaType == MediaTypeVideo) { // 保存视频
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:mediaURL];
                    } else if (mediaType == MediaTypeImage) { // 保存图片
                        UIImage *image = [UIImage imageWithContentsOfFile:mediaURL.path];
                        if (image) {
                            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                        }
                    } else if (mediaType == MediaTypeAudio) {
                        // 音频不保存到相册，直接跳过
                    }
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{ // 回到主线程
                        if (success && mediaType != MediaTypeAudio) { // 音频不提示保存成功
                            [self showToast:[NSString stringWithFormat:@"%@已保存到相册", [self getMediaTypeDescription:mediaType]]];
                        }
                        if (completion) completion();
                    });
                    // 非音频类型，保存后清理临时文件
                    if (mediaType != MediaTypeAudio) {
                        [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:nil];
                    }
                }];
            }
        } else { // 未授权
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"需要相册权限才能保存"];
                if (completion) completion();
            });
        }
    }];
}

// 获取媒体类型的中文字符串描述 (用于提示信息)
+ (NSString *)getMediaTypeDescription:(MediaType)mediaType {
    switch (mediaType) {
        case MediaTypeVideo: return @"视频";
        case MediaTypeImage: return @"图片";
        case MediaTypeAudio: return @"音频";
        case MediaTypeHeic: return @"表情包"; // HEIC 通常用作表情包
        case MediaTypeLivePhoto: return @"实况照片";
        default: return @"文件"; // 未知类型
    }
}

// 下载并保存单个媒体 (图片/视频/HEIC保存相册, 音频弹出分享)
+ (void)downloadAndSaveMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(NSURL *localFileURL, NSError *error))completion {
    if (!url) { // URL 无效
        if (completion) completion(nil, [NSError errorWithDomain:@"DYYYError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"URL为空"}]);
        return;
    }

    // 调用带进度的下载方法 (这里 progressBlock 传 nil)
    [self downloadMediaWithProgress:url mediaType:mediaType progress:nil completion:^(BOOL success, NSURL *fileURL) {
        if (success && fileURL) { // 下载成功
            if (mediaType == MediaTypeAudio) { // 如果是音频
                // 弹出系统分享菜单 (AirDrop, 保存到文件等)
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
                    // 分享完成后清理临时文件 (包括取消分享)
                    activityVC.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]; // 清理下载的音频文件
                        // 注意：这里没有处理 activityError
                    };
                    UIViewController *topVC = [self getActiveTopController]; // 获取顶层控制器来 present
                    if (topVC) {
                        [topVC presentViewController:activityVC animated:YES completion:nil];
                    }
                    // 即使分享未完成，也立即回调 completion (表示下载成功)
                    if (completion) completion(fileURL, nil);
                });
            } else { // 其他类型 (图片/视频/HEIC)
                // 调用保存到相册的方法
                [self saveMedia:fileURL mediaType:mediaType completion:^{
                    // saveMedia 内部会清理文件，这里只需回调
                    if (completion) completion(fileURL, nil);
                }];
            }
        } else { // 下载失败
            if (completion) completion(nil, [NSError errorWithDomain:@"DYYYError" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"下载失败"}]);
        }
    }];
}

// 修改实况照片下载和保存的主要流程
+ (void)downloadAndSaveLivePhotoWithImageURL:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(BOOL success, NSError *error))completion {
    if (!imageURL || !videoURL) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DYYYError" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"URL无效"}]);
        return;
    }

    // 显示进度视图
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYDownloadProgressView *progressView = [[DYYYDownloadProgressView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [progressView show];
        progressView.progressLabel.text = @"准备下载实况照片...";

        // 创建下载任务组
        dispatch_group_t group = dispatch_group_create();
        __block NSURL *localImageURL = nil;
        __block NSURL *localVideoURL = nil;
        
        // 下载图片
        dispatch_group_enter(group);
        [self downloadMediaWithProgress:imageURL mediaType:MediaTypeImage progress:^(float progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:progress * 0.5]; // 图片占50%进度
                progressView.progressLabel.text = [NSString stringWithFormat:@"下载图片...%d%%", (int)(progress * 100)];
            });
        } completion:^(BOOL success, NSURL *fileURL) {
            localImageURL = success ? fileURL : nil;
            dispatch_group_leave(group);
        }];

        // 下载视频
        dispatch_group_enter(group);
        [self downloadMediaWithProgress:videoURL mediaType:MediaTypeVideo progress:^(float progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:0.5 + progress * 0.5]; // 视频占后50%进度
                progressView.progressLabel.text = [NSString stringWithFormat:@"下载视频...%d%%", (int)(progress * 100)];
            });
        } completion:^(BOOL success, NSURL *fileURL) {
            localVideoURL = success ? fileURL : nil;
            dispatch_group_leave(group);
        }];

        // 处理下载完成
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (localImageURL && localVideoURL) {
                progressView.progressLabel.text = @"处理实况照片...";
                // 处理并保存实况照片
                [[DYYYManager shared] saveLivePhoto:localImageURL.path videoUrl:localVideoURL.path];
                [progressView dismiss];
                if (completion) completion(YES, nil);
            } else {
                [progressView dismiss];
                [self showToast:@"下载实况照片失败"];
                if (completion) completion(NO, [NSError errorWithDomain:@"DYYYError" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"下载失败"}]);
            }
            
            // 清理临时文件
            if (localImageURL) [[NSFileManager defaultManager] removeItemAtURL:localImageURL error:nil];
            if (localVideoURL) [[NSFileManager defaultManager] removeItemAtURL:localVideoURL error:nil];
        });
    });
}

// 下载并保存所有图片 (无进度) - 简单包装带进度的方法
+ (void)downloadAndSaveAllImages:(NSArray<NSString *> *)imageURLStrings completion:(void (^)(NSInteger successCount, NSInteger failureCount))completion {
    if (imageURLStrings.count == 0) { // URL 列表为空
        if (completion) completion(0, 0);
        return;
    }

    // 过滤掉无效的 URL 字符串
    NSMutableArray *validURLs = [NSMutableArray array];
    for (NSString *urlString in imageURLStrings) {
        if (urlString && urlString.length > 0) {
            [validURLs addObject:urlString];
        }
    }

    if (validURLs.count == 0) { // 没有有效的 URL
        if (completion) completion(0, 0);
        return;
    }

    // 调用带进度的批量下载方法，但不关心进度回调
    [self downloadAllImagesWithProgress:validURLs progress:nil completion:^(NSInteger successCount, NSInteger totalCount) {
        NSInteger failureCount = totalCount - successCount; // 计算失败数量
        if (completion) completion(successCount, failureCount); // 回调成功和失败数
    }];
}

// 添加图片分析方法实现
+ (MediaType)analyzeImageType:(NSURL *)url {
    if (!url) return MediaTypeImage;
    
    NSString *pathExtension = url.pathExtension.lowercaseString;
    
    // 先检查特殊格式
    if ([pathExtension isEqualToString:@"gif"]) {
        return MediaTypeGIF;
    }
    
    if ([pathExtension isEqualToString:@"heic"] || 
        [pathExtension isEqualToString:@"heif"]) {
        return MediaTypeHeic;
    }
    
    // 默认返回普通图片类型
    return MediaTypeImage;
}

// 获取最佳视频尺寸方法
+ (CGSize)getOptimalVideoSizeFromImages:(NSArray<NSURL *> *)imageURLs {
    CGSize maxSize = CGSizeMake(1920, 1080); // 默认最大4K
    CGSize optimalSize = CGSizeMake(1280, 720); // 默认720p
    
    if (imageURLs.count == 0) return optimalSize;
    
    // 从第一张图片获取尺寸
    UIImage *firstImage = [UIImage imageWithContentsOfFile:imageURLs.firstObject.path];
    if (!firstImage) return optimalSize;
    
    CGSize imageSize = firstImage.size;
    
    // 确保尺寸不超过最大值
    if (imageSize.width > maxSize.width || imageSize.height > maxSize.height) {
        // 等比缩放
        CGFloat ratio = MIN(maxSize.width / imageSize.width, maxSize.height / imageSize.height);
        optimalSize = CGSizeMake(imageSize.width * ratio, imageSize.height * ratio);
    } else {
        optimalSize = imageSize;
    }
    
    // 确保宽高是偶数(视频编码要求)
    optimalSize.width = (int)(optimalSize.width / 2) * 2;
    optimalSize.height = (int)(optimalSize.height / 2) * 2;
    
    return optimalSize;
}

// 图片缩放方法
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    if (!image) return nil;
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resizedImage ?: image;
}

// 添加视频保存到相册方法实现
+ (void)saveVideoToAlbum:(NSURL *)videoURL completion:(void (^)(void))completion {
    if (!videoURL) {
        if (completion) completion();
        return;
    }
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        [self showToast:@"视频已保存到相册"];
                    } else {
                        NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                        [self showToast:[NSString stringWithFormat:@"视频保存失败: %@", errorMsg]];
                    }
                    
                    if (completion) completion();
                });
                
                // 删除临时文件
                [[NSFileManager defaultManager] removeItemAtURL:videoURL error:nil];
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"需要相册权限才能保存视频"];
                if (completion) completion();
            });
        }
    }];
}

// 添加合成视频方法实现
+ (void)synthesizeVideoFromImages:(NSArray<NSURL *> *)imageURLs 
                       audioURL:(NSURL *)audioURL 
                  progressView:(DYYYDownloadProgressView *)progressView 
                   completion:(void (^)(BOOL success, NSError *error))completion {
    if (imageURLs.count == 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DYYYError" code:-10 
                                           userInfo:@{NSLocalizedDescriptionKey: @"没有图片可用于合成"}]);
        return;
    }
    
    // 获取图片尺寸
    CGSize videoSize = [self getOptimalVideoSizeFromImages:imageURLs];
    
    // 创建临时输出路径
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"synth_video_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]]];
    NSURL *outputURL = [NSURL fileURLWithPath:tempFilePath];
    
    // 创建AssetWriter (使用默认的30fps)
    AVAssetWriter *writer = [self createAssetWriterWithURL:outputURL size:videoSize frameRate:30.0f];
    
    if (!writer) {
        if (completion) completion(NO, [NSError errorWithDomain:@"DYYYError" code:-11 
                                           userInfo:@{NSLocalizedDescriptionKey: @"无法创建视频写入器"}]);
        return;
    }
    
    // 开始处理合成
    [self processVideoSynthesis:writer 
                     imageURLs:imageURLs 
                    frameRate:30.0f 
                    duration:3.0f 
                    targetSize:videoSize 
                   progressView:progressView 
                    completion:completion];
}

// 创建写入器 - 简化版，转发到带frameRate的方法
+ (AVAssetWriter *)createAssetWriterWithURL:(NSURL *)outputURL size:(CGSize)size {
    // 默认使用30fps
    return [self createAssetWriterWithURL:outputURL size:size frameRate:30.0f];
}

// 使用标准的 Objective-C 初始化方法，替换原来的 %ctor
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 记录初始化状态
        NSLog(@"[DYYY] DYYYManager 初始化完成");
        
        // 使用运行时的方式处理Swift类的评论复制功能
        Class commentCopyElementClass = objc_getClass("_TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement");
        if (commentCopyElementClass && ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableCommentCopyText"] ||
                                       [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCommentCopyText"])) {
            // 查找actionImpl方法的SEL
            SEL actionImplSel = NSSelectorFromString(@"actionImpl");
            if ([commentCopyElementClass instancesRespondToSelector:actionImplSel]) {
                // 保存原始方法实现
                Method originalMethod = class_getInstanceMethod(commentCopyElementClass, actionImplSel);
                IMP originalImp = method_getImplementation(originalMethod);
                
                // 创建替代方法实现
                IMP newImp = imp_implementationWithBlock(^(id self) {
                    // 尝试获取评论上下文
                    id commentContext = nil;
                    Ivar contextIvar = class_getInstanceVariable([self class], "_commentPageContext");
                    if (contextIvar) {
                        commentContext = object_getIvar(self, contextIvar);
                    }
                    
                    // 尝试获取评论内容
                    if (commentContext) {
                        id comment = nil;
                        if ([commentContext respondsToSelector:NSSelectorFromString(@"selectdComment")]) {
                            comment = [commentContext performSelector:NSSelectorFromString(@"selectdComment")];
                        }
                        
                        if (comment) {
                            NSString *content = nil;
                            if ([comment respondsToSelector:NSSelectorFromString(@"content")]) {
                                content = [comment performSelector:NSSelectorFromString(@"content")];
                            }
                            
                            if (content) {
                                [[UIPasteboard generalPasteboard] setString:content];
                                [DYYYManager showToast:@"评论文本已复制到剪贴板"];
                                return;
                            }
                        }
                    }
                    
                    // 如果无法获取内容或处理失败，调用原始实现
                    ((void (*)(id, SEL))originalImp)(self, actionImplSel);
                });
                
                // 替换原始方法实现
                method_setImplementation(originalMethod, newImp);
            }
        }
    });
}
@end
