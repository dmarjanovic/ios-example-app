//
//  WelcomeViewController.m
//  OneginiDemoApp
//
//  Created by Sergey Butenko on 3/5/16.
//  Copyright © 2016 Onegini. All rights reserved.
//

#import "WelcomeViewController.h"
#import "AuthCoordinator.h"

@interface WelcomeViewController()

@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@end

@implementation WelcomeViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if ([[AuthCoordinator sharedInstance] isRegistered]){
        [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];
    } else {
        [self.loginButton setTitle:@"Register" forState:UIControlStateNormal];
    }
}

- (IBAction)login:(id)sender {
    [[AuthCoordinator sharedInstance] login];
}

@end
