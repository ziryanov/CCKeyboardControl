//
//  CCKeyboardControl.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 25/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "CCKeyboardControl.h"
#import <objc/runtime.h>

#define CCKeyboardControlLoggingEnabled

@interface UIViewController(CCKeyboardControl)

+ (UIViewController *)cc_KeyboardControlTopViewController;

@end

@implementation UIViewController(CCKeyboardControl)

+ (UIViewController *)cc_KeyboardControlTopViewController
{
    return [[UIApplication sharedApplication].keyWindow.rootViewController cc_KeyboardControlTopViewController];
}

- (UIViewController *)cc_KeyboardControlTopViewController
{
    if ([self isKindOfClass:[UITabBarController class]])
        return [((UITabBarController *)self).selectedViewController cc_KeyboardControlTopViewController];
    if ([self isKindOfClass:[UINavigationController class]])
        return [((UINavigationController *)self).topViewController cc_KeyboardControlTopViewController];
    if (self.presentedViewController)
        return [self.presentedViewController cc_KeyboardControlTopViewController];
    if (self.childViewControllers.count)
        return [[self.childViewControllers lastObject] cc_KeyboardControlTopViewController];
    return self;
}

@end

@interface CCKeyboardControlHelper : NSObject

@property (nonatomic) CGFloat keyboardTriggerOffset;

@property (nonatomic, weak) UIView *sview;
@property (nonatomic, copy) CCKeyboardDidMoveBlock frameBasedKeyboardDidMoveBlock;
@property (nonatomic, copy) CCKeyboardDidMoveBlock constraintBasedKeyboardDidMoveBlock;
@property (nonatomic) CFAbsoluteTime animationStartAbsoluteTime;

@property (nonatomic, getter = isKeyboardOpened) BOOL keyboardOpened;

@property (nonatomic) UIPanGestureRecognizer *keyboardPanRecognizer;

@end

@implementation CCKeyboardControlHelper

+ (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}

+ (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end

@interface UIView(CCKeyboardControl_private)

@property (nonatomic, readonly) CCKeyboardControlHelper *ccKeyboardControlHelper;
@property (nonatomic, readonly) UIGestureRecognizer *ccScreenEdgePanRecognizer;
@property (nonatomic, getter = isKeyboardOpened) BOOL keyboardOpened;

@end

@implementation UIView (CCKeyboardControl)

+ (void)load
{
    SEL originalSelector = NSSelectorFromString(@"dealloc");;
    SEL swizzledSelector = @selector(swizzled_dealloc);
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
    BOOL added = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (added)
        class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)swizzled_dealloc
{
    [self removeKeyboardControl];
    [self swizzled_dealloc];
}

- (void)addKeyboardPanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock
{
    [self addKeyboardNonpanningWithFrameBasedActionHandler:didMoveFrameBasesBlock constraintBasedActionHandler:didMoveConstraintBasesBlock];
    
    if (!self.ccKeyboardControlHelper.keyboardPanRecognizer)
    {
        self.ccKeyboardControlHelper.keyboardPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(CCKeyboardControlPanGestureAction:)];
        self.ccKeyboardControlHelper.keyboardPanRecognizer.delegate = (id<UIGestureRecognizerDelegate>)[CCKeyboardControlHelper class];
        [self.ccKeyboardControlHelper.keyboardPanRecognizer setCancelsTouchesInView:NO];
        [self addGestureRecognizer:self.ccKeyboardControlHelper.keyboardPanRecognizer];
    }
}

- (void)addKeyboardNonpanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock
{
    if (!didMoveFrameBasesBlock && !didMoveConstraintBasesBlock)
        return;
    self.ccKeyboardControlHelper.sview = self;
    self.ccKeyboardControlHelper.frameBasedKeyboardDidMoveBlock = didMoveFrameBasesBlock;
    self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock = didMoveConstraintBasesBlock;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CCKeyboardControlKeyboardWillShow:) name:UIKeyboardWillShowNotification object:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CCKeyboardControlKeyboardDidShow:) name:UIKeyboardDidShowNotification object:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CCKeyboardControlKeyboardWillHide:) name:UIKeyboardWillHideNotification object:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CCKeyboardControlKeyboardDidHide:) name:UIKeyboardDidHideNotification object:0];
}

- (void)removeKeyboardControl
{
    if (self.getCCKeyboardControlHelper.frameBasedKeyboardDidMoveBlock || self.getCCKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGRect)keyboardFrameInView
{
    return [self convertRect:self.cc_KeyboardView.frame fromView:self.cc_KeyboardWindow];
}

- (CGFloat)keyboardTriggerOffset
{
    return self.ccKeyboardControlHelper.keyboardTriggerOffset;
}

- (void)setKeyboardTriggerOffset:(CGFloat)keyboardTriggerOffset
{
    self.ccKeyboardControlHelper.keyboardTriggerOffset = keyboardTriggerOffset;
}

- (BOOL)keyboardOpened
{
    return self.ccKeyboardControlHelper.keyboardOpened;
}

//private methods
- (void)cc_callBlocksWithKeyboardYOriging:(CGFloat)keyboardYOriging state:(CCKeyboardControlState)state force:(BOOL)force
{
    CGRect keyboardFrame = self.cc_KeyboardView.frame;
    keyboardFrame.origin.y = keyboardYOriging;
    keyboardFrame = [self convertRect:keyboardFrame fromView:self.cc_KeyboardWindow];
    
#ifdef CCKeyboardControlLoggingEnabled
    if (force)
        NSLog(@"force");
#endif
    
    if (self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
    {
        if (force)
        {
            keyboardFrame.origin.y += 1;
            self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock(keyboardFrame, state);
            [self layoutSubviews];
            keyboardFrame.origin.y -= 1;
        }
        self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock(keyboardFrame, state);
    }
    [UIView animateWithDuration:0 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (self.ccKeyboardControlHelper.frameBasedKeyboardDidMoveBlock)
            self.ccKeyboardControlHelper.frameBasedKeyboardDidMoveBlock(keyboardFrame, state);
        if (self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
            [self layoutSubviews];
    } completion:0];
}

- (void)cc_simulateKeyboardDissapearingWithoutAnimation
{
    if (!self.cc_KeyboardView)
        return;
    [self cc_callBlocksWithKeyboardYOriging:self.cc_KeyboardWindow.height state:CCKeyboardControlStateClosing force:NO];
}

- (void)cc_processNotificationWithoutAnimation:(NSNotification *)notification state:(CCKeyboardControlState)state force:(BOOL)force
{
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];    
    CGRect frame = [self convertRect:keyboardEndFrame fromView:self.cc_KeyboardWindow];
    [self cc_callBlocksWithKeyboardYOriging:frame.origin.y state:state force:force];
}

- (void)cc_animateWithNotification:(NSNotification *)notification state:(CCKeyboardControlState)state
{
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];

    CGRect frame = [self convertRect:keyboardEndFrame fromView:self.cc_KeyboardWindow];
    if (self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
        self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock(frame, state);
    
    [UIView beginAnimations:@"CCKeyboardControlAnimation" context:0];
    UIViewAnimationCurve curve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&curve];
    [UIView setAnimationCurve:curve];
    double duration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [UIView setAnimationDuration:duration];
    
    if (self.ccKeyboardControlHelper.frameBasedKeyboardDidMoveBlock)
        self.ccKeyboardControlHelper.frameBasedKeyboardDidMoveBlock(frame, state);
    if (self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
        [self layoutSubviews];
    
    [UIView commitAnimations];
    self.ccKeyboardControlHelper.animationStartAbsoluteTime = CFAbsoluteTimeGetCurrent();
}

- (void)cc_checkForNotFinishedAnimation:(NSNotification *)notification state:(CCKeyboardControlState)state
{
    double duration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [UIView setAnimationDuration:duration];
    
    if (self.ccKeyboardControlHelper.animationStartAbsoluteTime > 0 && CFAbsoluteTimeGetCurrent() - self.ccKeyboardControlHelper.animationStartAbsoluteTime < duration)
        [self cc_processNotificationWithoutAnimation:notification state:CCKeyboardControlStateOpening force:YES];
    self.ccKeyboardControlHelper.animationStartAbsoluteTime = 0;
}

//---------------------------------------------

- (BOOL)cc_isHorizontalKeyboardAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];
    return keyboardBeginFrame.origin.x != 0 || keyboardEndFrame.origin.x != 0;
}

- (BOOL)cc_isWrongKeyboardAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    return keyboardBeginFrame.origin.y > self.cc_KeyboardWindow.height;
}

- (BOOL)cc_isFakeAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];
    return CGRectEqualToRect(keyboardBeginFrame, keyboardEndFrame);
}

//---------------------------------------------

- (BOOL)cc_isOnTopController
{
    if (![UIViewController cc_KeyboardControlTopViewController].navigationController)
        return YES;
    UIView *controllerView = self;
    while (controllerView && ![controllerView isKindOfClass:NSClassFromString(@"UIViewControllerWrapperView")])
    {
        if (controllerView == [UIViewController cc_KeyboardControlTopViewController].view)
            return YES;
        controllerView = controllerView.superview;
    }
    return NO;
}

- (BOOL)сс_isOnPenultimateControllerOnNavigationController
{
    UIViewController *underTopController = [UIViewController cc_KeyboardControlTopViewController];
    if (underTopController.navigationController.viewControllers.count <= 1)
        return NO;
    underTopController = underTopController.navigationController.viewControllers[underTopController.navigationController.viewControllers.count - 2];
    
    UIView *controllerView = self;
    while (controllerView && ![controllerView isKindOfClass:NSClassFromString(@"UIViewControllerWrapperView")])
    {
        if (controllerView == underTopController.view)
            return YES;
        controllerView = controllerView.superview;
    }
    return NO;
}

- (BOOL)cc_isOnControllerWhatHasPresentedController
{
    UIViewController *underTopModalController = [UIViewController cc_KeyboardControlTopViewController].presentingViewController;
    if ([underTopModalController isKindOfClass:[UITabBarController class]])
        underTopModalController = ((UITabBarController *)underTopModalController).selectedViewController;
    if ([underTopModalController isKindOfClass:[UINavigationController class]])
        underTopModalController = ((UINavigationController *)underTopModalController).topViewController;
    if (!underTopModalController)
        return NO;
    UIView *controllerView = self;
    while (controllerView && ![controllerView isKindOfClass:NSClassFromString(@"UIViewControllerWrapperView")])
    {
        if (controllerView == underTopModalController.view)
            return YES;
        controllerView = controllerView.superview;
    }
    return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////

- (void)CCKeyboardControlKeyboardWillShow:(NSNotification *)notification
{
    [self logNoti:notification command:@"willShow"];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.cc_KeyboardView.hidden = NO;
    });
    
    if (!self.cc_isOnTopController || !self.window)
        return;
    if (self.ccScreenEdgePanRecognizer.state == UIGestureRecognizerStateBegan)
        return;
    
    if ([self cc_isHorizontalKeyboardAnimation:notification] || [self cc_isWrongKeyboardAnimation:notification] || [self cc_isFakeAnimation:notification])
        [self cc_processNotificationWithoutAnimation:notification state:CCKeyboardControlStateOpening force:NO];
    else
        [self cc_animateWithNotification:notification state:CCKeyboardControlStateOpening];
}

- (void)CCKeyboardControlKeyboardDidShow:(NSNotification *)notification
{
    [self logNoti:notification command:@"didShow"];
    [self cc_checkForNotFinishedAnimation:notification state:CCKeyboardControlStateOpening];
}

- (void)CCKeyboardControlKeyboardWillHide:(NSNotification *)notification
{
    [self logNoti:notification command:@"willHide"];
    
    if ((!self.cc_isOnTopController && !self.cc_isOnControllerWhatHasPresentedController) || !self.window)
        return;
    if (self.ccScreenEdgePanRecognizer.state == UIGestureRecognizerStateBegan)
        return;

    if ([self cc_isHorizontalKeyboardAnimation:notification] || [self cc_isFakeAnimation:notification])
        [self cc_simulateKeyboardDissapearingWithoutAnimation];
    else
        [self cc_animateWithNotification:notification state:CCKeyboardControlStateClosing];
}

- (void)CCKeyboardControlKeyboardDidHide:(NSNotification *)notification
{
    [self logNoti:notification command:@"didHide"];
    [self cc_checkForNotFinishedAnimation:notification state:CCKeyboardControlStateClosing];
}

////////////////////////////////////////////////////////////////////////////////////////////////

- (void)CCKeyboardControlPanGestureAction:(UIPanGestureRecognizer *)gesture
{
    CGFloat keyboardYOriging = self.cc_KeyboardView.yOrigin;
    CGFloat keyboardHeight = self.cc_KeyboardView.height;
    
    CGFloat touchLocationInKeyboardWindow = [gesture locationInView:self.cc_KeyboardWindow].y;
    
    switch (gesture.state)
    {
        case UIGestureRecognizerStateBegan:
            gesture.maximumNumberOfTouches = gesture.numberOfTouches;
            self.cc_KeyboardView.userInteractionEnabled = NO;
            break;
        case UIGestureRecognizerStateChanged:
        {
            keyboardYOriging = touchLocationInKeyboardWindow + self.keyboardTriggerOffset;
            keyboardYOriging = MIN(keyboardYOriging, self.cc_KeyboardWindow.height);
            keyboardYOriging = MAX(keyboardYOriging, self.cc_KeyboardWindow.height - keyboardHeight);
            
            if (keyboardYOriging != self.cc_KeyboardView.yOrigin)
            {
                self.cc_KeyboardView.yOrigin = keyboardYOriging;
                [self cc_callBlocksWithKeyboardYOriging:keyboardYOriging state:CCKeyboardControlStatePanning force:NO];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            if (keyboardYOriging == self.cc_KeyboardWindow.height - keyboardHeight)
                break;
            CGPoint velocity = [gesture velocityInView:self.cc_KeyboardView];
            keyboardYOriging = velocity.y < 0 ? self.cc_KeyboardWindow.height - keyboardHeight : self.cc_KeyboardWindow.height;
            
            CGFloat diff = fabs(keyboardYOriging - self.cc_KeyboardView.yOrigin);
            if (diff > 0)
            {
                CGRect frame = self.cc_KeyboardView.frame;
                frame.origin.y = keyboardYOriging;
                if (self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock)
                    self.ccKeyboardControlHelper.constraintBasedKeyboardDidMoveBlock(frame, CCKeyboardControlStatePanning);

                [UIView animateWithDuration:.1 + .2 * (diff / keyboardHeight) delay:.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self.cc_KeyboardView.yOrigin = keyboardYOriging;
                    [self cc_callBlocksWithKeyboardYOriging:keyboardYOriging state:CCKeyboardControlStatePanning force:NO];
                    
                } completion:^(__unused BOOL finished){
                    if (velocity.y >= 0)
                        [self hideKeyboard];
                }];
            }
            else
            {
                if (keyboardYOriging == self.cc_KeyboardWindow.height)
                    [self hideKeyboard];
            }
            gesture.maximumNumberOfTouches = NSUIntegerMax;
            self.cc_KeyboardView.userInteractionEnabled = YES;
            break;
        }
        default:
            break;
    }
}

////////////////////////////////////////////////////////////////////////

- (UIView *)cc_KeyboardControlFirstResponder
{
    return [self cc_KeyboardControlFindFirstResponder:self];
}

- (UIView *)cc_KeyboardControlFindFirstResponder:(UIView *)view
{
    if ([view isFirstResponder])
        return view;
    UIView *found = 0;
    for (UIView *v in view.subviews)
    {
        found = [self cc_KeyboardControlFindFirstResponder:v];
        if (found)
            break;
    }
    return found;
}

//////////////////////// properties
- (UIWindow *)cc_KeyboardWindow
{
    if ([UIApplication sharedApplication].windows.count == 1)
        return 0;
    return [[UIApplication sharedApplication].windows lastObject];
}

- (UIView *)cc_KeyboardView
{
    for (UIView *v in self.cc_KeyboardWindow.subviews)
    {
        if ([v isKindOfClass:NSClassFromString(@"UIPeripheralHostView")])
            return v;
    }
    return 0;
}

- (UIGestureRecognizer *)ccScreenEdgePanRecognizer
{
    static UIGestureRecognizer *__ccScreenEdgePanRecognizer = 0;
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __ccScreenEdgePanRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:0 action:0];
        ((UIScreenEdgePanGestureRecognizer *)__ccScreenEdgePanRecognizer).edges = UIRectEdgeLeft;
        __ccScreenEdgePanRecognizer.delegate = (id<UIGestureRecognizerDelegate>)[CCKeyboardControlHelper class];
    });
    if (!__ccScreenEdgePanRecognizer.view && self.window)
        [self.window addGestureRecognizer:__ccScreenEdgePanRecognizer];
#endif
    return __ccScreenEdgePanRecognizer;
}

char *ccKeyboardControlHelperKey;
- (CCKeyboardControlHelper *)getCCKeyboardControlHelper
{
    return objc_getAssociatedObject(self, &ccKeyboardControlHelperKey);
}

- (CCKeyboardControlHelper *)ccKeyboardControlHelper
{
    CCKeyboardControlHelper *ccKeyboardControlHelper = [self getCCKeyboardControlHelper];
    if (!ccKeyboardControlHelper)
    {
        ccKeyboardControlHelper = [CCKeyboardControlHelper new];
        objc_setAssociatedObject(self, &ccKeyboardControlHelperKey, ccKeyboardControlHelper, OBJC_ASSOCIATION_RETAIN);
    }
    return ccKeyboardControlHelper;
}

- (void)setKeyboardOpened:(BOOL)keyboardOpened
{
    [self willChangeValueForKey:@"keyboardOpened"];
    self.ccKeyboardControlHelper.keyboardOpened = keyboardOpened;
    [self didChangeValueForKey:@"keyboardOpened"];
}

//////////////////////// logging
static NSMutableArray *loggingPointers;
int indexOfPointer(void *pointer)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loggingPointers = [NSMutableArray new];
    });
    NSUInteger index = [loggingPointers indexOfObject:[NSValue valueWithPointer:pointer]];
    if (index == NSNotFound)
    {
        index = loggingPointers.count;
        [loggingPointers addObject:[NSValue valueWithPointer:pointer]];
    }
    return (int)index + 1;
}
- (void)logNoti:(NSNotification *)notification command:(NSString *)command
{
#ifdef CCKeyboardControlLoggingEnabled
    CGRect keyboardBeginFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrameWindow];
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    double duration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [UIView setAnimationDuration:duration];
    
    NSLog(@"%d(fr %d ot %d utm %d wi %d sep %d) %@ %.2f %@ %@", indexOfPointer((__bridge void *)self), self.cc_KeyboardControlFirstResponder ? 1 : 0, self.cc_isOnTopController, self.cc_isOnControllerWhatHasPresentedController, self.window ? 1 : 0, self.ccScreenEdgePanRecognizer.state, command, duration, NSStringFromCGPoint(keyboardBeginFrameWindow.origin), NSStringFromCGPoint(keyboardEndFrameWindow.origin));
#endif
}

@end

@implementation UIView (CCKeyboardControl_deprecated)

- (void)addKeyboardPanningWithActionHandler:(CCKeyboardDidMoveBlock)didMoveBlock
{
    [self addKeyboardPanningWithFrameBasedActionHandler:didMoveBlock constraintBasedActionHandler:0];
}

- (void)addKeyboardNonpanningWithActionHandler:(CCKeyboardDidMoveBlock)didMoveBlock
{
    [self addKeyboardNonpanningWithFrameBasedActionHandler:didMoveBlock constraintBasedActionHandler:0];
}

- (void)hideKeyboard
{
    self.cc_KeyboardView.hidden = YES;
    [self.cc_KeyboardControlFirstResponder resignFirstResponder];
}

@end

