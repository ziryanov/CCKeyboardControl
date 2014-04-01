//
//  ViewController2.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 28/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "ViewController2.h"
#import "CCKeyboardControl.h"

@interface ViewController2 ()

@end

@implementation ViewController2

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateTableViewInsetWithKeyboardFrame:self.view.keyboardFrameInView];
    
    __weak typeof(self) wself = self;
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
        [wself updateTableViewInsetWithKeyboardFrame:keyboardFrameInView];
        wself.bottomPanel.maxY = keyboardFrameInView.origin.y;
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

@end
