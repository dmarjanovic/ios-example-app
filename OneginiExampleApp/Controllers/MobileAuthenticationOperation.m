//
// Copyright (c) 2016 Onegini. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "MobileAuthenticationOperation.h"
#import "PinViewController.h"
#import "PushConfirmationViewController.h"
#import "PinErrorMapper.h"
#import "ZFModalTransitionAnimator.h"

@interface MobileAuthenticationOperation ()

@property (nonatomic) PinViewController *pinViewController;
@property (nonatomic) UIViewController *preservedViewController;

@property (nonatomic) BOOL preparedForPresentation;

@end

@implementation MobileAuthenticationOperation

#pragma mark - Init

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo userClient:(ONGUserClient *)userClient navigationController:(UINavigationController *)navigationController
{

    self = [super init];
    if (self) {
        _userInfo = userInfo;
        _userClient = userClient;
        _navigationController = navigationController;
    }

    return self;
}

#pragma mark - Execution

- (void)executionStarted
{
    // This method is going to be invoked from the background queue, so we need move execution to the main.
    // Result of calling the SDK from the background thread is undefined.
    dispatch_async(dispatch_get_main_queue(), ^{
        self.pinViewController = [[PinViewController alloc] init];
        [self.userClient handleMobileAuthenticationRequest:self.userInfo delegate:self];
    });
}

- (void)executionFinished
{
    if (self.preservedViewController) {
        [self.navigationController presentViewController:self.preservedViewController animated:YES completion:nil];
    }
}

/// There might be an active alert (or any other controller) presented on the top of the screen. We need to preserve it somehow.
/// You also might want to add new transparent UIWindow on top and present your confirmation completely independently from the
/// current UI state.
- (void)performSafeConfirmationPresentation:(void (^)(void))presentation
{
    if (self.preparedForPresentation) {
        presentation();
    } else {
        self.preparedForPresentation = YES;

        if (self.navigationController.presentedViewController) {
            self.preservedViewController = self.navigationController.presentedViewController;
            [self.navigationController dismissViewControllerAnimated:YES completion:presentation];
        } else {
            presentation();
        }
    }
}

#pragma mark - ONGMobileAuthenticationRequestDelegate

- (void)userClient:(ONGUserClient *)userClient didReceiveConfirmationChallenge:(void (^)(BOOL confirmRequest))confirmation forRequest:(ONGMobileAuthenticationRequest *)request
{
    PushConfirmationViewController *pushVC = [PushConfirmationViewController new];
    pushVC.pushMessage.text = request.message;
    pushVC.pushTitle.text = [NSString stringWithFormat:@"Confirm push - %@", request.userProfile.profileId];
    pushVC.pushConfirmed = ^(BOOL confirmed) {
        [self.navigationController popViewControllerAnimated:YES];
        confirmation(confirmed);
    };

    [self performSafeConfirmationPresentation:^{
        [self.navigationController pushViewController:pushVC animated:YES];
    }];

}

/**
 * SDK sends challenge in order to authenticated User. In case User has entered invalid pin or SDK wasn't able to
 * connect to the server this method will be invoked again. Developer may want to inspect `challenge.error` property to understand reason of error.
 * In addition to error property `challenge` also maintains `previousFailureCount`, `maxFailureCount` and `remainingFailureCount` that
 * reflects number of attemps left. User gets deregistered once number of attempts exceeded.
 *
 * Note: during errors that are not related to the PIN validation such as network errors attempts counter remains untouched.
 */
- (void)userClient:(ONGUserClient *)userClient didReceivePinChallenge:(ONGPinChallenge *)challenge forRequest:(ONGMobileAuthenticationRequest *)request
{
    [self.pinViewController reset];
    self.pinViewController.mode = PINCheckMode;
    self.pinViewController.pinLength = 5;
    self.pinViewController.customTitle = [NSString stringWithFormat:@"Push with pin - %@", challenge.userProfile.profileId];
    __weak MobileAuthenticationOperation *weakSelf = self;

    self.pinViewController.pinEntered = ^(NSString *pin) {
        [weakSelf.navigationController popViewControllerAnimated:YES];
        [challenge.sender respondWithPin:pin challenge:challenge];
    };

    [self performSafeConfirmationPresentation:^{
        // It is up to the developer to decide when and how to show PIN entry view controller.
        // For simplicity of the example app we're checking the top-most view controller.
        if (![self.navigationController.topViewController isEqual:self.pinViewController]) {
            [self.navigationController pushViewController:self.pinViewController animated:YES];
        }

        if (challenge.error) {
            // Please read comments for the PinErrorMapper to understand intent of this class and how errors can be handled.
            NSString *description = [PinErrorMapper descriptionForError:challenge.error ofPinChallenge:challenge];
            [self.pinViewController showError:description];
        }
    }];
}

/**
 * In contract with -userClient:didReceivePinChallenge:forRequest: is not going to be called again in case or error - SDK fallbacks to the PIN instead.
 * This also doesn't affect on the PIN attempts count. Thats why we can skip any error handling for the fingerpint challenge.
 */
- (void)userClient:(ONGUserClient *)userClient didReceiveFingerprintChallenge:(ONGFingerprintChallenge *)challenge forRequest:(ONGMobileAuthenticationRequest *)request
{
    PushConfirmationViewController *pushVC = [PushConfirmationViewController new];
    pushVC.pushMessage.text = request.message;
    pushVC.pushTitle.text = [NSString stringWithFormat:@"Confirm push with fingerprint - %@", request.userProfile.profileId];
    pushVC.pushConfirmed = ^(BOOL confirmed) {
        [self.navigationController popViewControllerAnimated:YES];
        
        if (confirmed){
            [challenge.sender respondWithDefaultPromptForChallenge:challenge];
        } else {
            [challenge.sender cancelChallenge:challenge];
        }
    };

    [self performSafeConfirmationPresentation:^{
        [self.navigationController pushViewController:pushVC animated:YES];
    }];
}

- (void)userClient:(ONGUserClient *)userClient didHandleMobileAuthenticationRequest:(ONGMobileAuthenticationRequest *)request
{
    // Once SDK reported that the `request` has been handled we need to finish our operation and free-up queue.
    [self finish];
}

- (void)userClient:(ONGUserClient *)userClient didFailToHandleMobileAuthenticationRequest:(ONGMobileAuthenticationRequest *)request error:(NSError *)error
{
    if (error.code == ONGGenericErrorUserDeregistered || error.code == ONGGenericErrorDeviceDeregistered) {
        // In case the user is deregistered on the server side the SDK will return the ONGGenericErrorUserDeregistered error. There are a few reasons why this can
        // happen (e.g. the user has entered too many failed PIN attempts). The app needs to handle this situation by deleting any locally stored data for the
        // deregistered user.
        // In case the entire device registration has been removed from the Token Server the SDK will return the ONGGenericErrorDeviceDeregistered error. In this
        // case the application needs to remove any locally stored data that is associated with any user. It is probably best to reset the app in the state as if
        // the user is starting up the app for the first time.
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if (error.code == ONGMobileAuthenticationRequestErrorNotFound) {
        // For some reason the mobile authentication request cannot be found on the Token Server anymore. This can happen if a push notification
        // was delivered with a huge delay and a mobile authentication request was already removed from the Token Server because it expired.
    } else if (error.code == ONGGenericErrorActionCancelled) {
        // If a challenge has been cancelled then the ONGGenericErrorActionCancelled error is returned. You can use this error to determine whether a mobile
        // authentication request was cancelled. You can also ignore it if you are not interested in this.
    }

    // Once SDK reported that the `request` has been handled we need to finish our operation and free-up queue.
    [self finish];
}

@end
