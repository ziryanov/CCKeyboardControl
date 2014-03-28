//
//  BaseViewController.h
//  CCKeyboardControlExample
//
//  Created by ziryanov on 28/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BaseViewController : UIViewController

@property (nonatomic) BOOL keyboardOpened;

@property (nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) IBOutlet UIView *bottomPanel;
@property (nonatomic) IBOutlet UITextField *textField;

- (void)updateTableViewInsetWithKeyboardFrame:(CGRect)keyboardFrame;

@end
