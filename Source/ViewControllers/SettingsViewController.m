//
//  SettingsViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/2/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "SettingsViewController.h"
#import "LQAudioManager.h"
#import "AuthViewController.h"
#import "WelcomeViewController.h"
#import "HelpViewController.h"
#import "PushManager.h"
#import "MatchViewController.h"

// XCode is being annoying.
#import "iPadHelper.h"
#import "AppConstants.h"

@interface SettingsViewController ()
@property (nonatomic, strong) UIButton *soundButton;
@property (nonatomic, strong) UIButton *accountButton;
@property (nonatomic, strong) UIButton *helpButton;
@property (nonatomic, strong) UIButton *creditsButton;
@property (nonatomic, strong) UIButton *resignButton;
@property (nonatomic, strong) UILabel *idLabel;
@end

@implementation SettingsViewController

- (BOOL)shouldDisplayBackgroundBoardImage {
  return NO;
}

- (BOOL)shouldShowBackButton {
  return NO;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [TestFlight passCheckpoint:@"settingsViewed"];
  
  self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
  
  float w = self.view.bounds.size.width;
  float h = self.view.bounds.size.height;

  int vpadding = SCALED(22);

  float lx = w/4;
  float rx = w-w/4;

  self.accountButton = [self addButtonWithTitle:@"" // see below
                                          color:kGlossyBlackColor
                                       selector:@selector(loginOrLogout:)
                                         center:CGPointMake(lx, h/2-vpadding/2-kGlossyButtonHeight/2)];

  self.soundButton = [self addButtonWithTitle:[self soundButtonTitle]
                                        color:kGlossyGreenColor
                                     selector:@selector(toggleSounds:)
                                       center:CGPointMake(lx, h/2+vpadding/2+kGlossyButtonHeight/2)];

  self.helpButton = [self addButtonWithTitle:NSLocalizedString(@"How to play", nil)
                                       color:kGlossyGoldColor
                                    selector:@selector(showHelp:)
                                      center:CGPointMake(rx, h/2-vpadding/2-kGlossyButtonHeight/2)];

  [_helpButton setTitleColor:kGlossyBrownColor forState:UIControlStateNormal];
  _helpButton.titleLabel.shadowOffset = CGSizeZero;
  
  self.creditsButton = [self addButtonWithTitle:@"Credits"
                                          color:kGlossyBlueColor
                                       selector:@selector(showCredits:)
                                         center:CGPointMake(rx, h/2+vpadding/2+kGlossyButtonHeight/2)];

  self.resignButton = [self addButtonWithTitle:NSLocalizedString(@"Resign Match", nil)
                                         color:kGlossyRedColor
                                      selector:@selector(doResign:)
                                        center:CGPointMake(w/2,
                                                           CGRectGetMaxY(_creditsButton.frame)+kGlossyButtonHeight)];

  UIFont *idFont = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  self.idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, [@"X" sizeWithFont:idFont].height)];
  _idLabel.center = CGPointMake(w/2, CGRectGetMinY(_accountButton.frame) - vpadding*1.5);
  _idLabel.textAlignment = UITextAlignmentCenter;
  _idLabel.backgroundColor = [UIColor clearColor];
  _idLabel.textColor = [UIColor whiteColor];
  _idLabel.shadowColor = [UIColor darkGrayColor];
  _idLabel.shadowOffset = CGSizeMake(0, -1);
  _idLabel.font = idFont;
  [self.view addSubview:_idLabel];
}

- (BOOL)isMatchBeingViewed {
  id nav = [UIApplication sharedApplication].keyWindow.rootViewController;
  if ([nav isKindOfClass:UINavigationController.class])
    return [((UINavigationController *)nav).topViewController isKindOfClass:MatchViewController.class];
  return NO;
}

- (void)doResign:(id)sender {
  __weak id weakSelf = self;
  [self showConfirmAlertWithCaption:@"Really resign?"
                              block:^(int buttonPressed) {
                                if (buttonPressed == 1) {  // OK
                                  DLog(@"confirmed resignation");
                                  id nav = [[[weakSelf view] window] rootViewController];
                                  if ([nav isKindOfClass:UINavigationController.class]) {
                                    UINavigationController *navController = (UINavigationController *)nav;
                                    if ([navController.topViewController isKindOfClass:MatchViewController.class]) {
                                      MatchViewController *matchVC = (MatchViewController *)navController.topViewController;
                                      [matchVC resign];
                                      [weakSelf dismissViewControllerAnimated:YES completion:nil];
                                    }
                                  }
                                }
                              }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateUserContext];

  _resignButton.hidden = ![self isMatchBeingViewed];
}

- (void)updateUserContext {
  if (![PFUser currentUser]) {
    [_accountButton setTitle:NSLocalizedString(@"Account", nil) forState:UIControlStateNormal];

    _idLabel.hidden = YES;

    _resignButton.hidden = YES;

  } else {
    [_accountButton setTitle:NSLocalizedString(@"Logout", nil) forState:UIControlStateNormal];

    _idLabel.hidden = NO;
    _idLabel.text = [NSString stringWithFormat:@"You are logged in as %@", [[PFUser currentUser] usernameForDisplay]];
  }
}

- (NSString *)soundButtonTitle {
  BOOL enabled = [LQAudioManager sharedManager].soundEnabled;
  return enabled ? NSLocalizedString(@"Sound: on", nil) : NSLocalizedString(@"Sound: off", nil);
}

- (void)toggleSounds:(id)sender {
  NSLog(@"toggle sounds");
  LQAudioManager *audio = [LQAudioManager sharedManager];
  audio.soundEnabled = !audio.soundEnabled;
  if (audio.soundEnabled)
    [audio playEffect:kEffectPlayedWord];
  [_soundButton setTitle:[self soundButtonTitle] forState:UIControlStateNormal];
}

- (void)loginOrLogout:(id)sender {
  UINavigationController *nav = (UINavigationController *)self.view.window.rootViewController;
  if ([PFUser currentUser]) {
    DLog(@"logout");

    [[PushManager sharedManager] unsubscribeFromCurrentUserChannel];

    [PFUser logOut];
    [self updateUserContext];
    [nav popToRootViewControllerAnimated:NO];
  } else {
    DLog(@"maybe login/signup");
    [nav pushViewController:[AuthViewController controller] animated:NO];

    dispatch_async(dispatch_get_main_queue(), ^{
      [nav dismissViewControllerAnimated:NO completion:nil];
    });
  }
}

- (void)showCredits:(id)sender {
  [self showAlertWithCaption:@"Lexatron was made by Fictorial.\n\nThanks to all the play testers and thank you for playing!"
                     titles:@[ @"OK", @"Twitter", @"Facebook" ]
                colors:@[ kGlossyBlackColor, kGlossyLightBlueColor, kGlossyBlueColor ]
                       block:^(int buttonPressed) {
                         switch (buttonPressed) {
                           case 0:
                             break;

                           case 1:  // Twitter
                             [self launchTwitter];
                             break;

                           case 2:  // Facebook
                             [self launchFacebook];
                             break;
                             
                           default:
                             break;
                         }
                       }];
}

- (void)launchTwitter {
  NSString *url;

  if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
    url = @"twitter://user?screen_name=TheRealLexatron";
  } else {
    url = @"https://twitter.com/TheRealLexatron";
  }

  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)launchFacebook {
  NSString *url;
  if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fb://"]]) {
    url = @"fb://page/326462464094910";
  } else {
    url = @"http://www.facebook.com/pages/Fictorial/326462464094910";
  }
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)showHelp:(id)sender {
  [TestFlight passCheckpoint:@"helpViewed"];

  UINavigationController *nav = (UINavigationController *)self.view.window.rootViewController;

  [nav pushViewController:[HelpViewController controller] animated:NO];

  dispatch_async(dispatch_get_main_queue(), ^{
    [nav dismissViewControllerAnimated:NO completion:nil];
  });
}

@end
