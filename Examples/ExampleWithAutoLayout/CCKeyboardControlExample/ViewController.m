//
//  ViewController.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 25/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "ViewController.h"
#import "CCKeyboardControl.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) IBOutlet UIView *bottomPanel;
@property (nonatomic) IBOutlet NSLayoutConstraint *bottomPanelBottomConstraint;
@property (nonatomic) IBOutlet UITextField *textField;

- (IBAction)buttonPressed;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _bottomPanel.backgroundColor = [UIColor colorWithRed:(arc4random() % 255 / 255.) green:(arc4random() % 255 / 255.) blue:(arc4random() % 255 / 255.) alpha:1];
    _tableView.backgroundColor = [UIColor colorWithRed:(arc4random() % 255 / 255.) green:(arc4random() % 255 / 255.) blue:(arc4random() % 255 / 255.) alpha:1];
    
    __weak typeof(self) wself = self;
    [self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
        [wself updateTableViewInsetWithKeyboardFrame:keyboardFrameInView];
    } constraintBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
        wself.bottomPanelBottomConstraint.constant = wself.view.height - keyboardFrameInView.origin.y;
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.navigationController.isBeingPresented)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(closePressed)];
    
    [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:YES];
}

//- (void)viewDidAppear:(BOOL)animated
//{
//    [super viewDidAppear:animated];
//    if (_keyboardOpened)
//    {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [_textField becomeFirstResponder];
//            _keyboardOpened = NO;
//        });
//    }
//}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if (_keyboardOpened)
    {
        [_textField becomeFirstResponder];
        _keyboardOpened = NO;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.view.keyboardTriggerOffset = _bottomPanel.height;
    [self updateTableViewInsetWithKeyboardFrame:self.view.keyboardFrameInView];
}

- (void)updateTableViewInsetWithKeyboardFrame:(CGRect)keyboardFrame
{
    _tableView.contentInsetBottom = (self.view.height - keyboardFrame.origin.y) + _bottomPanel.height;
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
}

- (void)closePressed
{
    [self dismissViewControllerAnimated:YES completion:0];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section != 4 ? 1 : 15;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    switch (indexPath.section)
    {
        case 0:
            cell.textLabel.text = @"Push controller";
            cell.detailTextLabel.text = @"";
            break;
        case 1:
            cell.textLabel.text = @"Push controller with opened keyboard";
            cell.detailTextLabel.text = @"";
            break;
        case 2:
            cell.textLabel.text = @"Present controller";
            cell.detailTextLabel.text = @"";
            break;
        case 3:
            cell.textLabel.text = @"Present controller with opened keyboard";
            cell.detailTextLabel.text = @"";
            break;
        case 4:
            cell.textLabel.text = @"Cell";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)indexPath.row + 1];
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
        case 1:
        {
            //[_textField resignFirstResponder];
            ViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"ViewController"];
            if (indexPath.section == 1)
                controller.keyboardOpened = YES;
            controller.title = [NSString stringWithFormat:@"%d", (int)[self.navigationItem.title integerValue] + 1];
            [self.navigationController pushViewController:controller animated:YES];
            break;
        }
        case 2:
        case 3:
        {
            //[_textField resignFirstResponder];
            ViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"ViewController"];
            if (indexPath.section == 3)
                controller.keyboardOpened = YES;
            controller.title = [NSString stringWithFormat:@"%d", (int)[self.navigationItem.title integerValue] + 1];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:navController animated:YES completion:0];
            break;
        }
    }
}

- (IBAction)buttonPressed
{
    [_textField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [_textField resignFirstResponder];
    return YES;
}

@end
