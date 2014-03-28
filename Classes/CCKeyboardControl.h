//
//  CCKeyboardControl.h
//  CCKeyboardControlExample
//
//  Created by ziryanov on 25/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CCKeyboardControlState)
{
    CCKeyboardControlStateOpening = 0,
    CCKeyboardControlStatePanning = 1,
    CCKeyboardControlStateClosing = 2,
};

//#ifdef CCKeyboardControlCompatibilityWithDAKeyboardControl
//typedef void (^CCKeyboardDidMoveBlock)(CGRect keyboardFrameInView);
//#else
typedef void (^CCKeyboardDidMoveBlock)(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState);
//#endif

@interface UIView (CCKeyboardControl)

/** The keyboardTriggerOffset property allows you to choose at what point the
 user's finger "engages" the keyboard.
 */
@property (nonatomic) CGFloat keyboardTriggerOffset;

/** Adding pan-to-dismiss (functionality introduced in iMessages)
 @param didMoveBlock called everytime the keyboard is moved so you can update
 the frames of your views
 */
- (void)addKeyboardPanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock
                         constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock;


/** Adding keyboard awareness (appearance and disappearance only)
 @param didMoveBlock called everytime the keyboard is moved so you can update
 the frames of your views
 */
- (void)addKeyboardNonpanningWithFrameBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveFrameBasesBlock
                            constraintBasedActionHandler:(CCKeyboardDidMoveBlock)didMoveConstraintBasesBlock;


/** Returns the keyboard frame in the view 
  This property is NOT KVO compliant
 */
@property (nonatomic, readonly) CGRect keyboardFrameInView;


/** Returns if keyboard is opened
 This property is KVO compliant
 */
@property (nonatomic, readonly, getter = isKeyboardOpened) BOOL keyboardOpened;

/** You can call this method to remove keyboard action handler, but you don't have to because it invokes automatically in dealloc */
- (void)removeKeyboardControl;


@end

@interface UIView (CCKeyboardControl_deprecated)

- (void)addKeyboardPanningWithActionHandler:(CCKeyboardDidMoveBlock)didMoveBlock;
- (void)addKeyboardNonpanningWithActionHandler:(CCKeyboardDidMoveBlock)didMoveBlock;

- (void)hideKeyboard;

@end
