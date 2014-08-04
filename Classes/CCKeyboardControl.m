//
//  CCKeyboardControl.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 25/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "CCKeyboardControl.h"
#import <UIView+TKGeometry.h>
#import <objc/runtime.h>

//#define CCKeyboardControlLoggingEnabled

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

@interface UIView(CCKeyboardControl_protected)

+ (UIView *)cc_KeyboardView;

@end

@interface CCKeyboardControlHelper : NSObject

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
    if ([gestureRecognizer isMemberOfClass:[UIPanGestureRecognizer class]])
    {
        return [UIView cc_KeyboardView] && ![UIView cc_KeyboardView].hidden;
    }
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

static NSMutableArray *_cc_registeredViews;
+ (void)load
{
    _cc_registeredViews = [NSMutableArray new];
}

+ (void)enumerateRegisteredViewsHelper:(void(^)(CCKeyboardControlHelper *helper))block
{
    for (CCKeyboardControlHelper *helper in [_cc_registeredViews copy])
    {
        if (helper.sview == 0)
            [_cc_registeredViews removeObject:helper];
        else
            block(helper);
    }
}

- (void)addKeyboardPanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock
{
    [self addKeyboardNonpanningWithFrameBasedActionHandler:didMoveFrameBasesBlock constraintBasedActionHandler:didMoveConstraintBasesBlock];
    
    if (self.ccKeyboardControlHelper)
    {
        self.ccKeyboardControlHelper.keyboardPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(CCKeyboardControlPanGestureAction:)];
        self.ccKeyboardControlHelper.keyboardPanRecognizer.delegate = (id<UIGestureRecognizerDelegate>)[CCKeyboardControlHelper class];
        self.ccKeyboardControlHelper.keyboardPanRecognizer.cancelsTouchesInView = NO;
        [self addGestureRecognizer:self.ccKeyboardControlHelper.keyboardPanRecognizer];
    }
}

- (void)addKeyboardNonpanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock
{
    if (!didMoveFrameBasesBlock && !didMoveConstraintBasesBlock)
        return;
    
    [self removeKeyboardControl];
    CCKeyboardControlHelper *helper = [CCKeyboardControlHelper new];
    helper.sview = self;
    helper.frameBasedKeyboardDidMoveBlock = didMoveFrameBasesBlock;
    helper.constraintBasedKeyboardDidMoveBlock = didMoveConstraintBasesBlock;
    [_cc_registeredViews addObject:helper];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self.class selector:@selector(CCKeyboardControlKeyboardWillShow:) name:UIKeyboardWillShowNotification object:0];
        [[NSNotificationCenter defaultCenter] addObserver:self.class selector:@selector(CCKeyboardControlKeyboardDidShow:) name:UIKeyboardDidShowNotification object:0];
        [[NSNotificationCenter defaultCenter] addObserver:self.class selector:@selector(CCKeyboardControlKeyboardWillHide:) name:UIKeyboardWillHideNotification object:0];
        [[NSNotificationCenter defaultCenter] addObserver:self.class selector:@selector(CCKeyboardControlKeyboardDidHide:) name:UIKeyboardDidHideNotification object:0];
    });
}

- (void)removeKeyboardControl
{
    [self.class enumerateRegisteredViewsHelper:^(CCKeyboardControlHelper *helper) {
        if (helper.sview == self)
            [_cc_registeredViews removeObject:helper];
    }];
}

- (CGRect)keyboardFrameInView
{
    CGRect keyboardViewFrame = self.cc_KeyboardView ? self.cc_KeyboardView.frame : CGRectMake(0, [UIScreen mainScreen].bounds.size.height, 0, 0);
    return [self convertRect:keyboardViewFrame fromView:self.cc_KeyboardWindow];
}

char *keyboardTriggerOffsetKey;
- (CGFloat)keyboardTriggerOffset
{
    return [objc_getAssociatedObject(self, &keyboardTriggerOffsetKey) floatValue];
}

- (void)setKeyboardTriggerOffset:(CGFloat)keyboardTriggerOffset
{
    objc_setAssociatedObject(self, &keyboardTriggerOffsetKey, @(keyboardTriggerOffset), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)keyboardOpened
{
    return self.ccKeyboardControlHelper.keyboardOpened;
}

//private methods
- (void)cc_callBlocksWithKeyboardFrame:(CGRect)keyboardFrame state:(CCKeyboardControlState)state force:(BOOL)force
{
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
    CGRect const closingKeyboardFrame = CGRectMake(0, self.cc_KeyboardWindow.height, 0, 0);
    [self cc_callBlocksWithKeyboardFrame:closingKeyboardFrame state:CCKeyboardControlStateClosing force:NO];
}

- (void)cc_processNotificationWithoutAnimation:(NSNotification *)notification state:(CCKeyboardControlState)state force:(BOOL)force
{
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];    
    [self cc_callBlocksWithKeyboardFrame:keyboardEndFrame state:state force:force];
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

+ (BOOL)cc_isHorizontalKeyboardAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];
    return keyboardBeginFrame.origin.x != 0 || keyboardEndFrame.origin.x != 0;
}

+ (BOOL)cc_isWrongKeyboardAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    return keyboardBeginFrame.origin.y > self.cc_KeyboardWindow.height;
}

+ (BOOL)cc_isFakeAnimation:(NSNotification *)notification
{
    CGRect keyboardBeginFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrame];
    CGRect keyboardEndFrame;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrame];
    return CGRectEqualToRect(keyboardBeginFrame, keyboardEndFrame);
}

//---------------------------------------------

- (BOOL)cc_isOnTop
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
    if (!controllerView && [UIApplication sharedApplication].keyWindow.subviews.count > 1)
    {
        UIView *activeWindow = 0;
        for (UIView *view in [UIApplication sharedApplication].keyWindow.subviews)
        {
            if (!view.hidden)
                activeWindow = view;
        }
        UIView *sview = self;
        while (sview)
        {
            if (sview == activeWindow)
                return YES;
            sview = sview.superview;
        }
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

+ (void)CCKeyboardControlKeyboardWillShow:(NSNotification *)notification
{
    [self logNoti:notification command:@"willShow"];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.cc_KeyboardView.hidden = NO;
    });
    
    if ([self ccScreenEdgePanRecognizer].state == UIGestureRecognizerStateBegan)
        return;
    
    [self enumerateRegisteredViewsHelper:^(CCKeyboardControlHelper *helper) {
        UIView *view = helper.sview;
        if (!view.cc_isOnTop || !view.window)
            return;
        
        if ([self cc_isHorizontalKeyboardAnimation:notification] || [self cc_isWrongKeyboardAnimation:notification] || [self cc_isFakeAnimation:notification])
            [view cc_processNotificationWithoutAnimation:notification state:CCKeyboardControlStateOpening force:NO];
        else
            [view cc_animateWithNotification:notification state:CCKeyboardControlStateOpening];
    }];
}

+ (void)CCKeyboardControlKeyboardDidShow:(NSNotification *)notification
{
    [self logNoti:notification command:@"didShow"];
    [self enumerateRegisteredViewsHelper:^(CCKeyboardControlHelper *helper) {
        [helper.sview cc_checkForNotFinishedAnimation:notification state:CCKeyboardControlStateOpening];
    }];
}

+ (void)CCKeyboardControlKeyboardWillHide:(NSNotification *)notification
{
    [self logNoti:notification command:@"willHide"];
    
    if (self.ccScreenEdgePanRecognizer.state == UIGestureRecognizerStateBegan)
        return;

    [self enumerateRegisteredViewsHelper:^(CCKeyboardControlHelper *helper) {
        UIView *view = helper.sview;
        if ((!view.cc_isOnTop && !view.cc_isOnControllerWhatHasPresentedController) || !view.window)
            return;

        if ([self cc_isHorizontalKeyboardAnimation:notification] || [self cc_isFakeAnimation:notification])
            [view cc_simulateKeyboardDissapearingWithoutAnimation];
        else
            [view cc_animateWithNotification:notification state:CCKeyboardControlStateClosing];
    }];
}

+ (void)CCKeyboardControlKeyboardDidHide:(NSNotification *)notification
{
    [self logNoti:notification command:@"didHide"];
    [self enumerateRegisteredViewsHelper:^(CCKeyboardControlHelper *helper) {
        [helper.sview cc_checkForNotFinishedAnimation:notification state:CCKeyboardControlStateClosing];
    }];
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
                [self cc_callBlocksWithKeyboardFrame:self.cc_KeyboardView.frame state:CCKeyboardControlStatePanning force:NO];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            self.cc_KeyboardView.userInteractionEnabled = YES;
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
                    [self cc_callBlocksWithKeyboardFrame:self.cc_KeyboardView.frame state:CCKeyboardControlStatePanning force:NO];
                    
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
    return [self.class cc_KeyboardWindow];
}

+ (UIWindow *)cc_KeyboardWindow
{
    __block UIWindow *cc_KeyboardWindow = 0;
    [[UIApplication sharedApplication].windows enumerateObjectsUsingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
        if ((*stop = [self cc_KeyboardView:window] != 0))
            cc_KeyboardWindow = window;
    }];
    if (cc_KeyboardWindow == 0 && [UIApplication sharedApplication].windows.count > 1)
        return [[UIApplication sharedApplication].windows lastObject];
    return cc_KeyboardWindow;
}

- (UIView *)cc_KeyboardView
{
    return [self.class cc_KeyboardView];
}

+ (UIView *)cc_KeyboardView
{
    return [self cc_KeyboardView:self.cc_KeyboardWindow];
}

+ (UIView *)cc_KeyboardView:(UIWindow *)window
{
    for (UIView *v in window.subviews)
    {
        if ([v isKindOfClass:NSClassFromString(@"UIPeripheralHostView")])
            return v;
    }
    return 0;
}

+ (UIGestureRecognizer *)ccScreenEdgePanRecognizer
{
    static UIGestureRecognizer *__ccScreenEdgePanRecognizer = 0;
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0)
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __ccScreenEdgePanRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:0 action:0];
        ((UIScreenEdgePanGestureRecognizer *)__ccScreenEdgePanRecognizer).edges = UIRectEdgeLeft;
        __ccScreenEdgePanRecognizer.delegate = (id<UIGestureRecognizerDelegate>)[CCKeyboardControlHelper class];
    });
    if (__ccScreenEdgePanRecognizer && !__ccScreenEdgePanRecognizer.view)
        [[UIApplication sharedApplication].keyWindow addGestureRecognizer:__ccScreenEdgePanRecognizer];
#endif
    return __ccScreenEdgePanRecognizer;
}

- (CCKeyboardControlHelper *)ccKeyboardControlHelper
{
    for (CCKeyboardControlHelper *helper in [_cc_registeredViews copy])
    {
        if (helper.sview == self)
            return helper;
    }
    return 0;
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

+ (void)logNoti:(NSNotification *)notification command:(NSString *)command
{
#ifdef CCKeyboardControlLoggingEnabled
    CGRect keyboardBeginFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] getValue: &keyboardBeginFrameWindow];
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    double duration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [UIView setAnimationDuration:duration];
    
    NSLog(@"%@ %.2f %@ %@", command, duration, NSStringFromCGPoint(keyboardBeginFrameWindow.origin), NSStringFromCGPoint(keyboardEndFrameWindow.origin));
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

