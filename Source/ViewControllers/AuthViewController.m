//
//  AuthViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "AuthViewController.h"
#import "SignupViewController.h"
#import "LoginViewController.h"
#import "PushManager.h"
#import "LQAudioManager.h"

@interface AuthViewController ()
@end

@implementation AuthViewController {
  UIButton *_loginButton;
  UIButton *_signupButton;
  UIButton *_fbButton;
  UIButton *_twButton;
}

- (void)loadView {
  [super loadView];

  float w = self.view.bounds.size.width;
  float h = [self effectiveViewHeight];

  float cx = w/2;
  float cy = h/2;

  float pad = SCALED(20);

  _loginButton = [self addButtonWithTitle:@"Login"
                                    color:kGlossyGreenColor
                                 selector:@selector(doLogin:)
                                   center:CGPointMake(cx, cy-pad/2-kGlossyButtonHeight-pad-kGlossyButtonHeight/2)];

  _signupButton = [self addButtonWithTitle:@"Sign up"
                                     color:kGlossyOrangeColor
                                  selector:@selector(doSignup:)
                                    center:CGPointMake(cx, cy-pad/2-kGlossyButtonHeight/2)];

  _fbButton = [self addButtonWithTitle:@"Use Facebook"
                                 color:kGlossyBlueColor
                              selector:@selector(doFacebook:)
                                center:CGPointMake(cx, cy+pad/2+kGlossyButtonHeight/2)];

  _twButton = [self addButtonWithTitle:@"Use Twitter"
                                 color:kGlossyLightBlueColor
                              selector:@selector(doTwitter:)
                                center:CGPointMake(cx, cy+pad/2+kGlossyButtonHeight+pad+kGlossyButtonHeight/2)];
}

- (void)slideInButtons {
  [self slideInFromBottom:@[_loginButton, _signupButton, _fbButton, _twButton]];
  [[LQAudioManager sharedManager] playEffect:kEffectSlide];
}

- (void)slideInFromBottom:(NSArray *)views {
  int i = 0;
  for (id view in views) {
    [view setHidden:YES];
    [self performBlock:^(id sender) {
      [view backInFrom:kFTAnimationBottom withFade:YES duration:0.5 delegate:nil];
    } afterDelay:i*0.1];
    i++;
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  if ([PFUser currentUser])
    [self.navigationController popViewControllerAnimated:NO];
  else
    [self slideInButtons];
}

- (void)doLogin:(id)sender {
  [self.navigationController pushViewController:[LoginViewController controller] animated:YES];
}

- (void)doSignup:(id)sender {
  [self.navigationController pushViewController:[SignupViewController controller] animated:YES];
}

- (void)doFacebook:(id)sender {
  __weak id weakSelf = self;

  // NB: offline_access seems to fix issues with Parse and FB tokens.
  // https://parse.com/tutorials/integrating-facebook
  
  NSArray *perms = @[];

  [PFFacebookUtils logInWithPermissions:perms block:^(PFUser *user, NSError *error) {
    if (!user) {
      DLog(@"The user cancelled the Facebook login.");
    } else {
      if (user.isNew) {
        DLog(@"User signed up and logged in through Facebook!");
      } else {
        DLog(@"User logged in through Facebook!");
      }

      [weakSelf showActivityHUD];

      DLog(@"getting 'me' info from FB...");

      [[PFFacebookUtils facebook] requestWithGraphPath:@"me" andDelegate:self];
    }
  }];
}

// Called when Facebook returns information about the user that logged in via Facebook
// (which creates a new user).

- (void)request:(PF_FBRequest *)request didLoad:(id)result {
  [self hideActivityHUD];

  DLog(@"got fb id & name for current user: %@, %@",
       [result objectForKey:@"id"],
       [result objectForKey:@"name"]);

  __weak id weakSelf = self;

  DLog(@"currentUser.isNew=%d", [PFUser currentUser].isNew);

  [[PFUser currentUser] setObject:[result objectForKey:@"id"] forKey:@"fbId"];

  NSString *name = [result objectForKey:@"name"];
  if (name.length >= kMaxUsernameLength) {
    name = [[name substringToIndex:kMaxUsernameLength - 3] stringByAppendingString:@"..."];
  }
  [[PFUser currentUser] setObject:name forKey:@"displayName"];

  [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"finalize logging in via Facebook", nil)];

      // Completely give up on the signup process through facebook-login.

      [PFUser logOut];
      [[PFUser currentUser] deleteEventually];

    } else {
      [[PushManager sharedManager] subscribeToCurrentUserChannel];
    }

    [[weakSelf navigationController] popViewControllerAnimated:NO];
  }];
}

- (void)request:(PF_FBRequest *)request didFailWithError:(NSError *)error {
  [self hideActivityHUD];

  [error showParseError:NSLocalizedString(@"fetch account info", nil)];

  // Completely give up on the signup process through facebook-login.

  [PFUser logOut];
  [[PFUser currentUser] deleteEventually];

  [self.navigationController popViewControllerAnimated:NO];
}

- (void)doTwitter:(id)sender {
  __weak id weakSelf = self;
  
  [PFTwitterUtils logInWithBlock:^(PFUser *user, NSError *error) {
    if (!user) {
      NSLog(@"The user cancelled the Twitter login.");
      return;
    } else {
      if (user.isNew) {
        NSLog(@"User signed up and logged in with Twitter!");
      } else {
        NSLog(@"User logged in with Twitter!");
      }

      [[weakSelf navigationController] popViewControllerAnimated:NO];
    }
  }];
}

@end
