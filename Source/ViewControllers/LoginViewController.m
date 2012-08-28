//
//  LoginViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "LoginViewController.h"
#import "PromptViewController.h"
#import "WelcomeViewController.h"
#import "ActivityViewController.h"

NSString * const kLoginNotification = @"UserDidLogin";

@interface LoginViewController ()
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@end

@implementation LoginViewController

- (void)loadView {
  [super loadView];

  int tfWidth  = SCALED(220);
  int tfHeight = SCALED(30);

  int buttonCenterX = self.view.bounds.size.width/2;

  self.usernameField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, tfWidth, tfHeight)];
  _usernameField.center = CGPointMake(buttonCenterX, SCALED(40));
  _usernameField.backgroundColor = [UIColor whiteColor];
  _usernameField.delegate = self;
  _usernameField.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  _usernameField.placeholder = @"Username";
  _usernameField.returnKeyType = UIReturnKeyNext;
  _usernameField.borderStyle = UITextBorderStyleRoundedRect;
  _usernameField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _usernameField.spellCheckingType = UITextSpellCheckingTypeNo;
  _usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
  [self.view addSubview:_usernameField];

  int margin = ISPAD ? 40 : 12;

  self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, tfWidth, tfHeight)];
  _passwordField.center = CGPointMake(buttonCenterX, CGRectGetMaxY(_usernameField.frame) + tfHeight/2 + margin);
  _passwordField.backgroundColor = [UIColor whiteColor];
  _passwordField.delegate = self;
  _passwordField.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  _passwordField.placeholder = @"Password";
  _passwordField.returnKeyType = UIReturnKeySend;
  _passwordField.secureTextEntry = YES;
  _passwordField.borderStyle = UITextBorderStyleRoundedRect;
  _passwordField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _passwordField.spellCheckingType = UITextSpellCheckingTypeNo;
  _passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
  [self.view addSubview:_passwordField];

  float w = self.view.bounds.size.width;

  [self addButtonWithTitle:@"Forgot?"
                     color:kGlossyBlackColor
                  selector:@selector(doPasswordReset:)
                    center:CGPointMake(w/3.2,
                                       CGRectGetMaxY(_passwordField.frame) + kGlossyButtonHeight/2+margin)];

  [self addButtonWithTitle:@"Login"
                     color:kGlossyGreenColor
                  selector:@selector(doLogin:)
                    center:CGPointMake(w-w/3.2,
                                       CGRectGetMaxY(_passwordField.frame) + kGlossyButtonHeight/2+margin)];
}

- (void)doLogin:(id)sender {
  [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
  [self login];
}

- (void)doPasswordReset:(id)sender {
  [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];

  __weak id weakSelf = self;

  PromptViewController *vc = [PromptViewController
                              controllerWithPrompt:@"Enter your email address"
                              placeholder:@"Email"
                              callback:^(NSString *text) {
                                LoginViewController *strongSelf = weakSelf;
                                [strongSelf.navigationController popViewControllerAnimated:NO];

                                NSString *email = [text trimWhitespace];

                                if (email.length == 0 || [email checkValidEmail] != nil)
                                  return;

                                DLog(@"reset %@", email);

                                [PFUser requestPasswordResetForEmailInBackground:email];

                                [weakSelf showNoticeAlertWithCaption:@"An email has been sent to the address entered with further instructions."];
                              }];

  [self.navigationController pushViewController:vc animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_usernameField becomeFirstResponder];
}

- (BOOL)_validate:(NSString *)input
        textField:(UITextField *)textField
         selector:(SEL)validator {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  NSString *error = [input performSelector:validator];
#pragma clang diagnostic pop

  if (!input)
    error = NSLocalizedString(@"Please enter a value", nil);

  if (error) {
    [textField resignFirstResponder];

    [self performBlock:^(id sender) {
      [textField showErrorTip:error];
    } afterDelay:0.7];

    [self performBlock:^(id sender) {
      [textField becomeFirstResponder];
    } afterDelay:4];

    return NO;
  }

  return YES;
}

- (void)login {

  BOOL usernameValid = [self _validate:_usernameField.text textField:_usernameField selector:@selector(checkValidUsername)];

  BOOL passwordValid = NO;
  if (usernameValid)
    passwordValid = [self _validate:_passwordField.text textField:_passwordField selector:@selector(checkValidPassword)];

  if (usernameValid && passwordValid) {
    [self showHUDWithActivity:YES caption:@"Logging in ..."];

    NSString *username = [[_usernameField.text trimWhitespace] lowercaseString];
    NSString *password = [_passwordField.text trimWhitespace];

    __weak id weakSelf = self;

    DLog(@"trying to login as %@", username);

    [self startTimeoutTimer];

    [PFUser logInWithUsernameInBackground:username
                                 password:password
                                    block:^(PFUser *user, NSError *error) {
                                      [weakSelf removeTimeoutTimer];
                                      [weakSelf hideActivityHUD];

                                      if (error) {
                                        DLog(@"login failed");
                                        
                                        if (error.code == kPFErrorObjectNotFound) {
                                          [self showAlertWithCaption:@"Login failed. Please try again."
                                                             titles:@[ @"OK" ]
                                                        colors:@[ kGlossyBlackColor ]
                                                               block:^(int buttonPressed) {
                                                                 [_usernameField becomeFirstResponder];
                                                               }];
                                        } else {
                                          [error showParseError:@"login"];
                                        }
                                      } else {
                                        DLog(@"user did login as %@", username);

                                        [TestFlight passCheckpoint:@"loggedIn"];

                                        UINavigationController *nav = (UINavigationController *)self.view.window.rootViewController;
                                        [nav popViewControllerAnimated:NO];
                                        
                                        if ([[nav topViewController] isKindOfClass:WelcomeViewController.class])
                                          [nav pushViewController:[ActivityViewController controller] animated:NO];
                                        
                                        [[NSNotificationCenter defaultCenter] postNotificationName:kLoginNotification object:nil];
                                      }
                                    }];
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == _usernameField) {
    [_passwordField becomeFirstResponder];
  } else if (textField == _passwordField) {
    [textField resignFirstResponder];
    [self login];
  }
  
  return YES;
}

@end
