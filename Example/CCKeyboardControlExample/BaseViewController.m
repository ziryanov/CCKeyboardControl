//
//  BaseViewController.m
//  CCKeyboardControlExample
//
//  Created by ziryanov on 28/03/14.
//  Copyright (c) 2014 ziryanov. All rights reserved.
//

#import "BaseViewController.h"

@interface BaseViewController ()

- (IBAction)buttonPressed;

@end

@implementation BaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _bottomPanel.backgroundColor = [UIColor colorWithRed:(arc4random() % 255 / 255.) green:(arc4random() % 255 / 255.) blue:(arc4random() % 255 / 255.) alpha:1];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.navigationController.isBeingPresented)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(closePressed)];
    
    [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:YES];
}

- (void)updateTableViewInsetWithKeyboardFrame:(CGRect)keyboardFrame
{
    self.tableView.contentInsetBottom = (self.view.height - keyboardFrame.origin.y) + self.bottomPanel.height;
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

- (void)closePressed
{
    [self dismissViewControllerAnimated:YES completion:0];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section != 6 ? 1 : 15;
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
            cell.textLabel.text = @"Resign then push";
            cell.detailTextLabel.text = @"";
            break;
        case 3:
            cell.textLabel.text = @"Resign then push controller with opened keyboard";
            cell.detailTextLabel.text = @"";
            break;
        case 4:
            cell.textLabel.text = @"Present controller";
            cell.detailTextLabel.text = @"";
            break;
        case 5:
            cell.textLabel.text = @"Present controller with opened keyboard";
            cell.detailTextLabel.text = @"";
            break;
        case 6:
            cell.textLabel.text = @"Cell";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)indexPath.row + 1];
            break;
    }
    return cell;
}

- (BaseViewController *)createViewController
{
    BaseViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:NSStringFromClass(self.class)];
    NSArray *titlePatrs = [self.navigationItem.title componentsSeparatedByString:@" "];
    controller.title = [NSString stringWithFormat:@"%@ %d", titlePatrs[0], (int)[titlePatrs[1] integerValue] + 1];
    return controller;
}

- (IBAction)navItemPressed {}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BaseViewController *controller = [self createViewController];
    if (indexPath.section % 2 == 1)
        controller.keyboardOpened = YES;

    switch (indexPath.section)
    {
        case 0:
        case 1:
        case 2:
        case 3:
        {
            if (indexPath.section > 1)
                [_textField resignFirstResponder];
            [self.navigationController pushViewController:controller animated:YES];
            break;
        }
        case 4:
        case 5:
        {
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