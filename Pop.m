#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Pop.h"

// =============================================================
// 间隔时间（单位：秒，6小时 = 6 * 60 * 60）
const NSTimeInterval ALERT_INTERVAL = (6 * 60 * 60);

// Base64 编码的图片数据
static NSString *const pxx917144686_ICON_BASE64 = @"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";

/**
 * 获取当前活动的顶层视图控制器
 * @return 当前活动的顶层视图控制器，如果未找到则返回 nil
 */
UIViewController* getActiveTopViewController() {
    UIWindow *window = nil;
    // 遍历所有已连接的场景，寻找前台活跃的场景
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && scene.windows.count > 0) {
            // 在活跃场景中寻找 key window
            for (UIWindow *win in scene.windows) {
                if (win.isKeyWindow) {
                    window = win;
                    break;
                }
            }
            if (window) break;
        }
    }
    
    if (!window) {
        return nil;
    }
    
    // 从根视图控制器开始，向上查找当前呈现的视图控制器
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

/*
 * 安全地呈现视图控制器，确保不会重复呈现
 * @param viewController 要呈现新控制器的视图控制器
 * @param toPresent 要呈现的视图控制器
 */
void safePresentViewController(UIViewController *viewController, UIViewController *toPresent) {
    // 检查是否已经呈现了其他控制器
    if (viewController.presentedViewController) {
        return;
    }
    // 在主线程上异步呈现视图控制器
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController presentViewController:toPresent animated:YES completion:nil];
    });
}

/*
 * 创建一个带有渐变背景和阴影效果的现代化按钮
 * @param title 按钮标题
 * @param gradientStartColor 渐变开始颜色
 * @param gradientEndColor 渐变结束颜色
 * @param target 按钮事件的目标对象
 * @return 配置好的按钮
 */
UIButton* createModernButton(NSString *title, UIColor *gradientStartColor, UIColor *gradientEndColor, id target) {
    // 创建自定义类型的按钮
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置按钮的固定尺寸
    [button.widthAnchor constraintEqualToConstant:120].active = YES;
    [button.heightAnchor constraintEqualToConstant:40].active = YES;

    // 创建渐变层
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = @[(id)gradientStartColor.CGColor, (id)gradientEndColor.CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1, 0.5);
    gradientLayer.frame = button.bounds;
    [button.layer insertSublayer:gradientLayer atIndex:0];

    // 设置按钮的圆角和阴影效果
    button.layer.cornerRadius = 20;
    button.layer.masksToBounds = YES;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.3;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    button.layer.shadowRadius = 6;

    // 设置按钮标题的属性（字体、颜色等）
    NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };
    [attributedTitle setAttributes:attributes range:NSMakeRange(0, title.length)];
    [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];

    // 添加按钮按下和松开的动画效果
    [button addTarget:target action:@selector(scaleDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:target action:@selector(scaleUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];

    return button;
}

// 底部弹窗呈现动画
@interface BottomSheetPresentationAnimation : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, weak) BottomSheetViewController *bottomSheet;
- (instancetype)initWithBottomSheet:(BottomSheetViewController *)bottomSheet;
@end

// 底部弹窗消失动画
@interface BottomSheetDismissalAnimation : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, weak) BottomSheetViewController *bottomSheet;
- (instancetype)initWithBottomSheet:(BottomSheetViewController *)bottomSheet;
@end

@implementation BottomSheetViewController {
    NSString *_title;
    NSString *_message;
    UIImage *_image;
    NSArray<UIButton *> *_actionButtons;
    UIView *_contentView;
}

@synthesize contentView = _contentView;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image actions:(NSArray<UIButton *> *)actionButtons {
    self = [super init];
    if (self) {
        _title = title;
        _message = message;
        _image = image;
        _actionButtons = actionButtons;
        // 设置自定义呈现样式
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.transitioningDelegate = self;
    }
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    return [[BottomSheetPresentationAnimation alloc] initWithBottomSheet:self];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return [[BottomSheetDismissalAnimation alloc] initWithBottomSheet:self];
}

- (CGFloat)preferredContentHeight {
    // 根据内容计算弹窗的首选高度
    CGFloat imageHeight = 100 + 20; // 图像高度 + 顶部间距
    CGFloat titleHeight = 30; // 标题大致高度
    
    // 计算消息文本高度
    UIFont *messageFont = [UIFont systemFontOfSize:15];
    CGFloat maxWidth = [UIScreen mainScreen].bounds.size.width - 80; // 考虑左右边距
    
    // 使用NSString的计算方法来确定文本高度
    CGRect boundingRect = [_message boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:@{NSFontAttributeName: messageFont}
                                                context:nil];
    CGFloat messageHeight = boundingRect.size.height + 20; // 文本高度 + 间距
    
    // 按钮高度加底部间距
    CGFloat buttonHeight = 40 + 30;
    
    // 计算总高度加上元素之间的边距
    CGFloat totalHeight = imageHeight + titleHeight + messageHeight + buttonHeight + 40;
    
    // 确保最小高度为屏幕高度的30%，最大高度为屏幕高度的80%
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat minHeight = screenHeight * 0.30;
    CGFloat maxHeight = screenHeight * 0.80;
    
    // 对于iPad或大屏设备，进一步限制最大宽度
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        maxHeight = MIN(maxHeight, 500);
    }
    
    return MIN(MAX(totalHeight, minHeight), maxHeight);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5]; // 半透明背景

    // 添加点击背景关闭手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];

    // 创建内容容器视图
    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentView.backgroundColor = [UIColor whiteColor];
    _contentView.layer.cornerRadius = 20;
    _contentView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner; // 仅顶部圆角
    _contentView.layer.shadowColor = [UIColor blackColor].CGColor;
    _contentView.layer.shadowOpacity = 0.3;
    _contentView.layer.shadowOffset = CGSizeMake(0, -4);
    _contentView.layer.shadowRadius = 6;
    [self.view addSubview:_contentView];

    // 添加图片视图
    UIImageView *imageView = [[UIImageView alloc] initWithImage:_image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:imageView];

    // 添加标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = _title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:titleLabel];

    // 添加消息标签
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = _message;
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.numberOfLines = 0;
    messageLabel.font = [UIFont systemFontOfSize:15];
    messageLabel.textColor = [UIColor systemBlueColor];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:messageLabel];

    // 创建按钮栈视图
    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:_actionButtons];
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    buttonStack.spacing = 20;
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:buttonStack];

    // 获取底部安全区域高度
    CGFloat bottomSafeArea = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
        bottomSafeArea = window.safeAreaInsets.bottom;
    }

    // 设置自动布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 内容视图约束
        [_contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // 图片约束 - 使用动态尺寸
        [imageView.centerXAnchor constraintEqualToAnchor:_contentView.centerXAnchor],
        [imageView.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:20],
        [imageView.widthAnchor constraintEqualToConstant:100],
        [imageView.heightAnchor constraintEqualToConstant:100],
        
        // 标题约束
        [titleLabel.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:10],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        
        // 消息约束
        [messageLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [messageLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [messageLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        
        // 按钮约束
        [buttonStack.topAnchor constraintEqualToAnchor:messageLabel.bottomAnchor constant:20],
        [buttonStack.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [buttonStack.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [buttonStack.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-(20 + bottomSafeArea)]
    ]];
}

// 处理背景点击事件
- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    if (!CGRectContainsPoint(_contentView.frame, location)) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// 支持手势识别
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 如果点击了内容视图，不处理手势
    return ![touch.view isDescendantOfView:_contentView];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // 处理设备旋转，重新调整弹窗位置
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // 重新设置弹窗位置
        self.contentView.frame = CGRectMake(0, size.height - [self preferredContentHeight], size.width, [self preferredContentHeight]);
    } completion:nil];
}

@end

@implementation BottomSheetPresentationAnimation

- (instancetype)initWithBottomSheet:(BottomSheetViewController *)bottomSheet {
    self = [super init];
    if (self) {
        _bottomSheet = bottomSheet;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.4;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *toView = toVC.view;
    CGRect finalFrame = transitionContext.containerView.bounds;
    
    // 计算弹窗高度
    CGFloat contentHeight = [_bottomSheet preferredContentHeight];
    
    // 设置初始位置（在屏幕底部之外）
    toView.frame = CGRectMake(0, finalFrame.size.height, finalFrame.size.width, finalFrame.size.height);
    [transitionContext.containerView addSubview:toView];
    
    // 设置内容视图初始位置
    _bottomSheet.contentView.frame = CGRectMake(0, finalFrame.size.height, finalFrame.size.width, contentHeight);
    
    // 执行动画
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
          delay:0
          usingSpringWithDamping:0.8
          initialSpringVelocity:0
          options:UIViewAnimationOptionCurveEaseInOut
          animations:^{
              // 背景淡入
              toView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
              // 内容视图从底部弹出
              self->_bottomSheet.contentView.frame = CGRectMake(0, finalFrame.size.height - contentHeight, finalFrame.size.width, contentHeight);
          } completion:^(BOOL finished) {
              [transitionContext completeTransition:finished];
          }];
}

@end

@implementation BottomSheetDismissalAnimation

- (instancetype)initWithBottomSheet:(BottomSheetViewController *)bottomSheet {
    self = [super init];
    if (self) {
        _bottomSheet = bottomSheet;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.3;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIView *fromView = fromVC.view;
    CGRect finalFrame = transitionContext.containerView.bounds;
    
    // 计算弹窗高度
    CGFloat contentHeight = [_bottomSheet preferredContentHeight];
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
          delay:0
          options:UIViewAnimationOptionCurveEaseInOut
          animations:^{
              // 背景淡出
              fromView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
              // 内容视图滑出屏幕
              self->_bottomSheet.contentView.frame = CGRectMake(0, finalFrame.size.height, finalFrame.size.width, contentHeight);
          } completion:^(BOOL finished) {
              [transitionContext completeTransition:finished];
          }];
}

@end

/**
 * 从 Base64 字符串创建图片
 * @return 解码后的图片
 */
UIImage *pxxImage() {
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:pxx917144686_ICON_BASE64 options:0];
    return [UIImage imageWithData:imageData];
}




// 使用 Theos 的 %hook 语法修改 UIViewController 的行为
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isFlowCompleted = [defaults boolForKey:@"IsFlowCompleted"];
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastDismissTime = [defaults doubleForKey:@"LastDismissTime"];
    NSTimeInterval timeDifference = currentTime - lastDismissTime;

    // 如果流程已完成且距离上次关闭时间不足 ALERT_INTERVAL，则不显示弹窗
    if (isFlowCompleted && timeDifference < ALERT_INTERVAL) {
        return;
    }

    static BOOL isAlertShown = NO;
    if (!isAlertShown) {
        isAlertShown = YES;
        [self showDisclaimerAlert];
    }
}

%new
- (void)showDisclaimerAlert {
    [self showThirdAlert];
}

%new
- (void)showThirdAlert {
    // 创建点赞和点踩按钮
    UIButton *thumbUpButton = createModernButton(@"👍", [UIColor systemGreenColor], [UIColor greenColor], self);
    [thumbUpButton addTarget:self action:@selector(thumbUpAction) forControlEvents:UIControlEventTouchUpInside];

    UIButton *thumbDownButton = createModernButton(@"👎", [UIColor systemRedColor], [UIColor systemPinkColor], self);
    [thumbDownButton addTarget:self action:@selector(thumbDownAction) forControlEvents:UIControlEventTouchUpInside];

    // 创建并显示底部弹窗
    BottomSheetViewController *bottomSheet = [[BottomSheetViewController alloc] initWithTitle:@"pxx 更新"
                                                                                     message:@"基于 huamidev 魔改～"
                                                                                       image:pxxImage()
                                                                                     actions:@[thumbUpButton, thumbDownButton]];
    safePresentViewController(getActiveTopViewController(), bottomSheet);
}

%new
- (void)thumbUpAction {
    UIViewController *topVC = getActiveTopViewController();
    if (topVC) {
        [topVC dismissViewControllerAnimated:YES completion:^{
            // 记录关闭时间并标记流程完成
            NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setDouble:currentTime forKey:@"LastDismissTime"];
            [defaults setBool:YES forKey:@"IsFlowCompleted"];
            [defaults synchronize];
        }];
    }
}

%new
- (void)thumbDownAction {
    [self dismissPresentedAlert];
    // 打开 GitHub 链接
    NSURL *url = [NSURL URLWithString:@"https://github.com/huami1314/DYYY"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

%new
- (void)dismissPresentedAlert {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = getActiveTopViewController();
        if (topVC) {
            [topVC dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

%new
- (void)scaleDown:(UIButton *)button {
    [UIView animateWithDuration:0.2 animations:^{
        button.transform = CGAffineTransformMakeScale(0.9, 0.9);
        button.layer.shadowOpacity = 0.4;
    }];
}

%new
- (void)scaleUp:(UIButton *)button {
    [UIView animateWithDuration:0.2 animations:^{
        button.transform = CGAffineTransformIdentity;
        button.layer.shadowOpacity = 0.3;
    }];
}

%end
