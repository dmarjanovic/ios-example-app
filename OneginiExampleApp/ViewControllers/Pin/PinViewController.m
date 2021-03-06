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

#import "PinViewController.h"
#import "UIBarButtonItem+Extension.h"

@interface PinViewController ()

@property (weak, nonatomic) IBOutlet UIView *pinSlotsView;
@property (nonatomic) NSArray *pinSlots;
@property (nonatomic) NSMutableArray *pinEntry;
@property (nonatomic) NSMutableArray *pinEntryToVerify;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;

@property (weak, nonatomic) IBOutlet UIButton *key1;
@property (weak, nonatomic) IBOutlet UIButton *key2;
@property (weak, nonatomic) IBOutlet UIButton *key3;
@property (weak, nonatomic) IBOutlet UIButton *key4;
@property (weak, nonatomic) IBOutlet UIButton *key5;
@property (weak, nonatomic) IBOutlet UIButton *key6;
@property (weak, nonatomic) IBOutlet UIButton *key7;
@property (weak, nonatomic) IBOutlet UIButton *key8;
@property (weak, nonatomic) IBOutlet UIButton *key9;
@property (weak, nonatomic) IBOutlet UIButton *key0;
@property (weak, nonatomic) IBOutlet UIButton *backKey;

@end

@implementation PinViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [UIBarButtonItem keyImageBarButtonItem];

    self.pinEntry = [NSMutableArray new];
    self.pinEntryToVerify = [NSMutableArray new];

    [self buildPinSlots];
}

- (void)buildPinSlots
{
    float pinSlotMargin = 10;
    float pinSlotWidth = (self.pinSlotsView.frame.size.width - (pinSlotMargin * (self.pinLength - 1))) / self.pinLength;

    NSMutableArray *pinSlotsArray = [NSMutableArray new];
    for (int i = 0; i < self.pinLength; i++) {
        CGRect pinSlotFrame = CGRectMake(i * (pinSlotWidth + pinSlotMargin), 0, pinSlotWidth, self.pinSlotsView.frame.size.height);
        UIView *pinSlotView = [self pinSlotWithFrame:pinSlotFrame];
        [pinSlotsArray addObject:pinSlotView];
        [self.pinSlotsView addSubview:pinSlotView];
    }
    self.pinSlots = [NSArray arrayWithArray:pinSlotsArray];
    [self selectSlotAtIndex:0];
}

- (UIView *)pinSlotWithFrame:(CGRect)frame
{
    UIView *pinSlotView = [[UIView alloc] initWithFrame:frame];
    pinSlotView.layer.cornerRadius = 5;
    pinSlotView.layer.borderColor = [UIColor blackColor].CGColor;
    pinSlotView.layer.borderWidth = 1;
    pinSlotView.layer.masksToBounds = YES;
    pinSlotView.backgroundColor = [UIColor whiteColor];
    return pinSlotView;
}

- (void)selectSlotAtIndex:(NSInteger)index
{
    ((UIView *)self.pinSlots[(NSUInteger)index]).layer.borderWidth = 2;
}

- (void)deselectSlotAtIndex:(NSInteger)index
{
    ((UIView *)self.pinSlots[(NSUInteger)index]).layer.borderWidth = 1;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.mode = self.mode;
}

- (void)showError:(NSString *)error
{
    self.errorLabel.text = error;
}

- (void)setMode:(PINEntryMode)mode
{
    _mode = mode;
    switch (mode) {
        case PINRegistrationMode:
            self.titleLabel.text = @"Create PIN";
            self.errorLabel.text = @"";
            break;
        case PINRegistrationVerifyMode:
            self.titleLabel.text = @"Verify PIN";
            self.errorLabel.text = @"";
            break;
        case PINCheckMode:
        default:
            self.titleLabel.text = @"Enter PIN";
            self.errorLabel.text = @"";
            break;
    }
    if (self.customTitle)
        self.titleLabel.text = self.customTitle;
}

- (IBAction)keyPressed:(UIButton *)key
{
    if (self.pinEntry == nil) {
        self.pinEntry = [NSMutableArray new];
    }

    if (self.pinEntry.count >= self.pinSlots.count) {
        return;
    }

    [self.pinEntry addObject:[NSString stringWithFormat:@"%ld", (long)key.tag]];

    [self evaluatePinState];
}

- (IBAction)backKeyPressed:(id)sender
{
    [self.pinEntry removeLastObject];

    [self updatePinStateRepresentation];
}

- (void)evaluatePinState
{
    [self updatePinStateRepresentation];

    if (self.pinEntry.count == self.pinSlots.count) {
        NSString *pincode = [self.pinEntry componentsJoinedByString:@""];
        switch (self.mode) {
            default:
            case PINCheckMode: {
                self.pinEntered(pincode, NO);
                break;
            }
            case PINRegistrationMode: {
                self.pinEntryToVerify = self.pinEntry.copy;
                self.mode = PINRegistrationVerifyMode;
                [self reset];
                break;
            }
            case PINRegistrationVerifyMode: {
                NSString *pincodeToVerify = [self.pinEntryToVerify componentsJoinedByString:@""];
                NSString *pincode = [self.pinEntry componentsJoinedByString:@""];
                if ([pincode isEqualToString:pincodeToVerify]) {
                    self.pinEntered(pincode, NO);
                } else {
                    self.mode = PINRegistrationMode;
                    [self reset];
                    self.errorLabel.text = @"The confirmation PIN does not match.";
                }
                break;
            }
        }
    }
}

- (void)reset
{
    for (NSUInteger i = 0; i < self.pinEntry.count; i++) {
        self.pinEntry[i] = @"#";
    }
    self.pinEntry = [NSMutableArray new];
    [self updatePinStateRepresentation];
}

- (void)updatePinStateRepresentation
{
    for (UIView *pinSlot in self.pinSlots) {
        [pinSlot.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    for (NSUInteger i = 0; i < self.pinEntry.count; i++) {
        UIView *slot = self.pinSlots[i];
        UIImage *pinIndicatorImage = [UIImage imageNamed:@"pin-occupied-ic"];
        UIImageView *pinIndicator = [[UIImageView alloc] initWithImage:pinIndicatorImage];
        pinIndicator.frame = CGRectMake(slot.frame.size.width / 2 - pinIndicatorImage.size.width / 2, slot.frame.size.height / 2 - pinIndicatorImage.size.height / 2, pinIndicatorImage.size.width, pinIndicatorImage.size.height);
        [slot addSubview:pinIndicator];
    }

    for (int i = 0; i < self.pinSlots.count; i++) {
        [self deselectSlotAtIndex:i];
    }

    if (self.pinEntry.count < self.pinSlots.count) {
        [self selectSlotAtIndex:self.pinEntry.count];
    }

    if (self.pinEntry.count == 0) {
        self.backKey.alpha = 0;
        self.backKey.enabled = NO;
    }
    else {
        self.backKey.alpha = 1;
        self.backKey.enabled = YES;
    }
}

- (IBAction)cancel:(id)sender {
    self.pinEntered(nil, YES);
}


@end
