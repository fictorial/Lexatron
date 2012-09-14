//
//  BaseViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/1/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "BaseViewController.h"
#import "ATMHud.h"
#import "SettingsViewController.h"
#import "LQAudioManager.h"
#import "UIImage+PDF.h"
#import "UIGlossyButton.h"

@interface BaseViewController ()
@property (nonatomic, assign, readwrite) BOOL isShowingHUD;
@end

@implementation BaseViewController {
  ATMHud *_hud;
  UILabel *_titleLabel;
  NSTimer *_timeoutTimer;
}

@synthesize requiresAuthenticatedUser=_requiresAuthenticatedUser;
@synthesize isShowingHUD=_isShowingHUD;

+ (id)controller {
  return [[self alloc] initWithNibName:nil bundle:nil];
}

- (CGFloat)effectiveViewHeight {
  CGFloat h =  ([UIApplication sharedApplication].statusBarHidden
          ? CGRectGetHeight(self.view.frame)
          : CGRectGetHeight(self.view.frame) - MIN(CGRectGetWidth([UIApplication sharedApplication].statusBarFrame),
                                                   CGRectGetHeight([UIApplication sharedApplication].statusBarFrame)));

  return h;
}

- (void)loadView {
  CGRect screenBounds = [UIScreen mainScreen].bounds;
  CGRect frame = CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width);   // Swap for landscape

  self.view = [[UIView alloc] initWithFrame:frame];
  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Cloth"]];

  self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;

  if ([self shouldDisplayBackgroundBoardImage]) {
    UIImageView *bgView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"Default"]];
    bgView.transform = CGAffineTransformMakeRotation(-M_PI_2);
    bgView.frame = self.view.bounds;
    [self.view addSubview:bgView];

    UIImage *boardImage = [UIImage imageWithPDFNamed:@"Board.pdf" atWidth:kBoardWidthPoints];
    UIImageView *boardView = [[UIImageView alloc] initWithImage:boardImage];
    boardView.frame = self.view.bounds;
    boardView.tag = kBoardViewTag;
    boardView.contentMode = UIViewContentModeCenter;
    [self.view addSubview:boardView];
  }

  if ([self shouldShowSettingsButton]) {
    BOOL isSettings = (self.class == [SettingsViewController class]);
    NSString *imageName = isSettings ? @"CloseButton" : @"SettingsButton";
    UIImage *settingsButtonImage = [UIImage imageWithName:imageName];
    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [settingsButton setImage:settingsButtonImage forState:UIControlStateNormal];
    [settingsButton sizeToFit];
    if (isSettings)
      settingsButton.center = CGPointMake(settingsButtonImage.size.width/2 + kButtonMargin,
                                          settingsButtonImage.size.height/2 + kButtonMargin);
    else
      settingsButton.center = CGPointMake(settingsButtonImage.size.width/2 + kButtonMargin,
                                          [self effectiveViewHeight] - settingsButtonImage.size.height/2 - kButtonMargin);
    [settingsButton addTarget:self action:@selector(showSettings:) forControlEvents:UIControlEventTouchUpInside];
    settingsButton.tag = kSettingsButtonTag;
    [settingsButton addStandardShadowing];
    [self.view addSubview:settingsButton];
  }

  _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SCALED(40))];
  _titleLabel.backgroundColor = [UIColor clearColor];
  _titleLabel.textAlignment = UITextAlignmentCenter;
  _titleLabel.textColor = [UIColor colorWithWhite:0.259 alpha:1.000];
  _titleLabel.font = [UIFont fontWithName:kFontName size:kFontSizeHeader];
  _titleLabel.text = self.title;
  _titleLabel.shadowColor = [UIColor colorWithWhite:1 alpha:0.4];
  _titleLabel.shadowOffset = CGSizeMake(0,1);
  [self.view addSubview:_titleLabel];

  UIImage *backButtonImage = [UIImage imageWithName:@"BackButton"];
  UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [backButton setImage:backButtonImage forState:UIControlStateNormal];
  [backButton sizeToFit];
  backButton.center = CGPointMake(backButtonImage.size.width/2+5, backButtonImage.size.height/2+5);
  backButton.tag = kBackButtonTag;
  backButton.hidden = YES;
  [backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:backButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  if (self.requiresAuthenticatedUser) {
    REQUIRE_USER;
  }

  [self.view bringSubviewToFront:[self.view viewWithTag:kSettingsButtonTag]];

  _titleLabel.hidden = !self.title;

  int vcCount = self.navigationController.viewControllers.count;
  BOOL showBack = [self shouldShowBackButton] && vcCount != 1;
  [[self.view viewWithTag:kBackButtonTag] setHidden:!showBack];

  if ([self shouldDisplayBackgroundBoardImage]) {
    UIView *boardView = [self.view viewWithTag:kBoardViewTag];
    boardView.alpha = 0;
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
      boardView.alpha = 1;
    } completion:^(BOOL finished) {
    }];
  }
}

- (BOOL)shouldShowBackButton {
  return YES;
}

- (BOOL)shouldDisplayBackgroundBoardImage {
  return YES;
}

- (BOOL)shouldShowSettingsButton {
  return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)goBack {
  [[LQAudioManager sharedManager] playEffect:kEffectBack];
  [self.navigationController popViewControllerAnimated:NO];
}

- (void)goBack:(id)sender {
  [self goBack];
}

- (UIButton *)makeButtonWithTitle:(NSString *)title color:(UIColor *)color selector:(SEL)selector {
  UIGlossyButton *button = [[UIGlossyButton alloc] initWithFrame:CGRectMake(0, 0, kGlossyButtonWidth, kGlossyButtonHeight)];

  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont fontWithName:kFontName size:kFontSizeButton];
  button.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.4];
  button.titleLabel.shadowOffset = CGSizeMake(0, -0.5);

  [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
  [button addTarget:self action:@selector(playButtonSound:) forControlEvents:UIControlEventTouchUpInside];

  button.layer.shadowColor = [UIColor blackColor].CGColor;
  button.layer.shadowOffset = CGSizeMake(0,2);
  button.layer.shadowOpacity = 0.6;
  button.layer.shadowRadius = 2;

  [button setTintColor:color];
  button.buttonCornerRadius = kGlossyButtonCornerRadius;
  [button setGradientType:kUIGlossyButtonGradientTypeLinearGlossyStandard];
  return button;
}

- (UIButton *)addButtonWithTitle:(NSString *)title
                           color:(UIColor *)color
                        selector:(SEL)selector
                          center:(CGPoint)centerPoint {

  UIButton *button = [self makeButtonWithTitle:title color:color selector:selector];
  button.center = centerPoint;
  [self.view addSubview:button];
  return button;
}

- (void)playButtonSound:(id)sender {
  [[LQAudioManager sharedManager] playEffect:kEffectSelect];
}

- (void)showSettings:(id)sender {
  if (self.class == [SettingsViewController class]) {
    [[LQAudioManager sharedManager] playEffect:kEffectBack];
    [self dismissViewControllerAnimated:YES completion:nil];
  } else {
    [[LQAudioManager sharedManager] playEffect:kEffectSelect];
    SettingsViewController *vc = [SettingsViewController controller];
    //    vc.modalTransitionStyle = UIModalTransitionStylePartialCurl;
    vc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self presentViewController:vc animated:YES completion:nil];
  }
}

- (BOOL)isShowingActivityHUD {
  return _hud != nil;
}

- (void)showHUDWithActivity:(BOOL)activity caption:(NSString *)caption {    // idempotent
  [_hud.view removeFromSuperview];

  self.isShowingHUD = NO;

  if (!caption && !activity)
    return;

  self.isShowingHUD = YES;

  _hud = [ATMHud new];

  if (activity) {
    [_hud setActivity:YES];
    [_hud setActivityStyle:UIActivityIndicatorViewStyleWhite];
  }

  if (caption)
    [_hud setCaption:caption];

  [self.view addSubview:_hud.view];
  [_hud show];
}

- (void)makeHUDNonModal {
  _hud.allowSuperviewInteraction = YES;
}

- (void)showActivityHUD {
  [self showHUDWithActivity:YES caption:nil];
}

- (void)hideActivityHUD {
  [_hud hide];
  self.isShowingHUD = NO;
}

- (void)showAlertWithCaption:(NSString *)message
                      titles:(NSArray *)titles
                      colors:(NSArray *)colors
                       block:(AlertBlock)block {
  
  [AlertView alertWithCaption:message
                 buttonTitles:titles
                 buttonColors:colors
                        block:block
                      forView:self.view];
}

- (void)showNoticeAlertWithCaption:(NSString *)caption {
  [self showAlertWithCaption:caption
                      titles:@[ @"OK" ]
                      colors:@[ kGlossyBlackColor ]
                       block:nil];
}

- (void)showConfirmAlertWithCaption:(NSString *)caption block:(AlertBlock)block {
  [self showAlertWithCaption:caption
                      titles:@[ @"No", @"Yes" ]
                      colors:@[ kGlossyBlackColor, kGlossyBlueColor ]
                       block:block];
}

- (void)showActionableAlertWithCaption:(NSString *)caption block:(AlertBlock)block {
  [self showAlertWithCaption:caption
                      titles:@[ @"Cancel", @"OK" ]
                      colors:@[ kGlossyBlackColor, kGlossyBlueColor ]
                       block:block];
}

- (void)hideAllAlerts {
  for (UIView *subview in self.view.subviews) {
    if ([subview isKindOfClass:AlertView.class])
      [subview removeFromSuperview];
  }
}

- (BOOL)isShowingAlert {
  for (UIView *subview in self.view.subviews) {
    if ([subview isKindOfClass:AlertView.class])
      return YES;
  }
  return NO;
}

- (void)bringAlertViewsToTheFront {
  for (UIView *subview in self.view.subviews) {
    if ([subview isKindOfClass:AlertView.class])
      [subview.superview bringSubviewToFront:subview];
  }
}

- (void)startTimeoutTimer {
  [self removeTimeoutTimer];
  
  _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kNetworkTimeoutDuration
                                                   target:self
                                                 selector:@selector(handleTimeout:)
                                                 userInfo:nil
                                                  repeats:NO];
}

- (void)removeTimeoutTimer {
  [_timeoutTimer invalidate];
  _timeoutTimer = nil;
}

- (void)handleTimeout:(id)sender {
  [self hideActivityHUD];
  [self showNoticeAlertWithCaption:@"Network problems? Please try again later!"];
  [self performBlock:^(id sender) {
    [self hideAllAlerts];
    [self goBack];
  } afterDelay:2.5];
}

@end
