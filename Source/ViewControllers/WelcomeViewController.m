//
//  WelcomeViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/2/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "WelcomeViewController.h"
#import "FindOpponentViewController.h"
#import "LQAudioManager.h"
#import "ActivityViewController.h"

enum {
  kWelcomeViewTag = 1,
  kPlusButtonTag
};

@interface WelcomeViewController ()
@property (nonatomic, assign) BOOL hasBeenViewed;
@end

@implementation WelcomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  UIImageView *titleView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"Title"]];
  titleView.frame = self.view.bounds;
  titleView.contentMode = UIViewContentModeBottomLeft;
  [self.view addSubview:titleView];
  
  UIButton *newMatchButton = [UIButton buttonWithType:UIButtonTypeCustom];
  newMatchButton.tag = kPlusButtonTag;
  [newMatchButton setImage:[UIImage imageWithName:@"NewMatchButton"] forState:UIControlStateNormal];
  [newMatchButton sizeToFit];
  newMatchButton.center = CGPointMake(self.view.bounds.size.width - newMatchButton.bounds.size.width/2-10,
                                      newMatchButton.bounds.size.height/2+10);
  [newMatchButton addTarget:self action:@selector(showFindOpponent:) forControlEvents:UIControlEventTouchUpInside];
  [newMatchButton addStandardShadowing];
  [self.view addSubview:newMatchButton];

  NSString *welcomeText = @"Welcome!\n\nTap the plus button to get started.";
  UIFont *welcomeFont = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  CGSize welcomeTextSize = [welcomeText sizeWithFont:welcomeFont
                                   constrainedToSize:CGSizeMake(self.view.bounds.size.width/4,
                                                                self.view.bounds.size.height)
                                       lineBreakMode:UILineBreakModeWordWrap];

  UIView *welcomeBg = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-welcomeTextSize.width-40,
                                                               CGRectGetMaxY(newMatchButton.frame)+20,
                                                               welcomeTextSize.width+20,
                                                               welcomeTextSize.height+30)];
  welcomeBg.layer.cornerRadius = 8;
  welcomeBg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
  welcomeBg.tag = kWelcomeViewTag;
  [self.view addSubview:welcomeBg];

  UILabel *welcomeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, welcomeBg.bounds.size.width-20, welcomeBg.bounds.size.height-20)];
  welcomeLabel.font = welcomeFont;
  welcomeLabel.lineBreakMode = UILineBreakModeWordWrap;
  welcomeLabel.numberOfLines = 4;
  welcomeLabel.textColor = [UIColor colorWithRed:0.898 green:0.875 blue:0.439 alpha:1.000];
  welcomeLabel.text = welcomeText;
  welcomeLabel.backgroundColor = [UIColor clearColor];
  [welcomeBg addSubview:welcomeLabel];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  if ([PFUser currentUser] != nil) {
    [self.navigationController pushViewController:[ActivityViewController controller] animated:NO];
    return;
  }

  if (!_hasBeenViewed) {
    self.hasBeenViewed = YES;

    [[self.view viewWithTag:kWelcomeViewTag] setHidden:YES];
    [self performBlock:^(id sender) {
      [[self.view viewWithTag:kWelcomeViewTag] popIn:0.5 delegate:nil];

      if (self.navigationController.topViewController == self)
        [[LQAudioManager sharedManager] playEffect:kEffectPrompt];
    } afterDelay:2];

    [[self.view viewWithTag:kPlusButtonTag] fadeIn:0.4 delegate:nil];
  }
}

- (void)showFindOpponent:(id)sender {
  [[LQAudioManager sharedManager] playEffect:kEffectSelect];
  FindOpponentViewController *vc = [FindOpponentViewController controller];
  [self.navigationController pushViewController:vc animated:NO];
}

- (BOOL)shouldShowBackButton {
  return NO;
}

- (BOOL)shouldDisplayBackgroundBoardImage {
  return NO;
}

@end
