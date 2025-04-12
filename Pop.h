#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef Pop_h
#define Pop_h

// 使用条件编译来处理 C++ 环境
#ifdef __cplusplus
extern "C" {
#endif

// 常量声明
extern const NSTimeInterval ALERT_INTERVAL;

// 类前置声明
@interface BottomSheetViewController : UIViewController <UIViewControllerTransitioningDelegate, UIGestureRecognizerDelegate>
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image actions:(NSArray<UIButton *> *)actionButtons;
- (CGFloat)preferredContentHeight;
@property (nonatomic, readonly) UIView *contentView;
@end

// 辅助函数声明
UIImage* pxxImage(void);
NSString* getAppVersion(void);
UIViewController* getActiveTopViewController(void);
void safePresentViewController(UIViewController *from, UIViewController *to);
UIButton* createModernButton(NSString *title, UIColor *gradientStartColor, UIColor *gradientEndColor, id target);

#ifdef __cplusplus
}  // 结束 extern "C" 块
#endif

// UIViewController 分类声明
@interface UIViewController (DYYYAdditions)
- (void)showDisclaimerAlert;
- (void)showThirdAlert;
- (void)dismissPresentedAlert;
- (void)thumbUpAction;
- (void)thumbDownAction;
- (void)scaleDown:(UIButton *)button;
- (void)scaleUp:(UIButton *)button;
@end

#endif /* Pop_h */
