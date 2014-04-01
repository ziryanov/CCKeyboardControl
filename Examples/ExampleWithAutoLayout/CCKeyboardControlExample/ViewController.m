//
//  ViewController.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 25/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "ViewController.h"
#import "CCKeyboardControl.h"

@interface ViewController ()

@property (nonatomic) IBOutlet NSLayoutConstraint *bottomPanelBottomConstraint;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    __weak typeof(self) wself = self;
    [self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
        if (keyboardState != CCKeyboardControlStatePanning)
            [wself updateTableViewInsetWithKeyboardFrame:keyboardFrameInView];
    } constraintBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
        wself.bottomPanelBottomConstraint.constant = wself.view.height - keyboardFrameInView.origin.y;
    }];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if (self.keyboardOpened)
    {
        [self.textField becomeFirstResponder];
        self.keyboardOpened = NO;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.view.keyboardTriggerOffset = self.bottomPanel.height;
    [self updateTableViewInsetWithKeyboardFrame:self.view.keyboardFrameInView];
}

- (IBAction)navItemPressed
{
    [self presentViewController:[[UIStoryboard storyboardWithName:@"Storyboard" bundle:0] instantiateInitialViewController] animated:YES completion:0];
}

@end
