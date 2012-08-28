//
//  SignupViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "SignupViewController.h"

NSString * const kSignupNotification = @"UserDidSignup";

@interface SignupViewController ()
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *emailField;
@end

@implementation SignupViewController

- (void)loadView {
  [super loadView];

  int tfWidth  = SCALED(200);
  int tfHeight = SCALED(30);

  float w= self.view.bounds.size.width;
  int buttonCenterX = w/3;

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
  _passwordField.returnKeyType = UIReturnKeyNext;
  _passwordField.secureTextEntry = YES;
  _passwordField.borderStyle = UITextBorderStyleRoundedRect;
  _passwordField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _passwordField.spellCheckingType = UITextSpellCheckingTypeNo;
  _passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
  [self.view addSubview:_passwordField];

  self.emailField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, tfWidth, tfHeight)];
  _emailField.center = CGPointMake(buttonCenterX, CGRectGetMaxY(_passwordField.frame) + tfHeight/2 + margin);
  _emailField.backgroundColor = [UIColor whiteColor];
  _emailField.delegate = self;
  _emailField.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  _emailField.placeholder = @"Email (optional)";
  _emailField.returnKeyType = UIReturnKeyGo;
  _emailField.borderStyle = UITextBorderStyleRoundedRect;
  _emailField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _emailField.spellCheckingType = UITextSpellCheckingTypeNo;
  _emailField.autocorrectionType = UITextAutocorrectionTypeNo;
  [self.view addSubview:_emailField];

  [self addButtonWithTitle:@"Signup"
                     color:kGlossyGreenColor
                  selector:@selector(doSignup:)
                    center:CGPointMake(w-w/4,
                                       CGRectGetMidY(_passwordField.frame))];
}

- (void)doSignup:(id)sender {
  [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];

  NSString *email = [_emailField.text trimWhitespace];
  if (email.length == 0) {
    __weak id weakSelf = self;
    [self showConfirmAlertWithCaption:@"Your email is only used to help your friends find you in Lexatron and for password resets.\n\nWould you like to enter your email address?"
                                block:^(int buttonPressed) {
                                  if (buttonPressed == 0) {
                                    [weakSelf signup];
                                  } else {
                                    [_emailField becomeFirstResponder];
                                  }
                                }];
  } else {
    [self signup];
  }
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

- (void)signup {
  BOOL usernameValid = [self _validate:_usernameField.text
                             textField:_usernameField
                              selector:@selector(checkValidUsername)];

  BOOL passwordValid = NO;
  if (usernameValid)
    passwordValid = [self _validate:_passwordField.text
                          textField:_passwordField
                           selector:@selector(checkValidPassword)];

  if (usernameValid && passwordValid) {
    NSString *email = [_emailField.text trimWhitespace];
    if (email.length > 0) {
      NSString *emailError = [email checkValidEmail];
      if (emailError) {
        [_emailField showErrorTip:emailError];
        return;
      }
    }

    [self showHUDWithActivity:YES caption:@"Signing up ..."];

    PFUser *user = [PFUser user];
    user.password = [_passwordField.text trimWhitespace];

    user.username = [[_usernameField.text trimWhitespace] lowercaseString];
    [user setObject:[_usernameField.text trimWhitespace] forKey:@"displayName"];

    if (email.length > 0)
      user.email = email;

    __weak id weakSelf = self;

    [self startTimeoutTimer];

    [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
      [weakSelf removeTimeoutTimer];
      [weakSelf hideActivityHUD];

      if (!error) {
        DLog(@"user did signup as %@", _usernameField.text);
        [TestFlight passCheckpoint:@"signedUp"];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSignupNotification object:nil];
        [[weakSelf navigationController] popViewControllerAnimated:YES];
      } else {
        if (error.code == kPFErrorUsernameTaken) {
          [weakSelf showAlertWithCaption:@"Username is already in use. Please enter another."
                                  titles:@[ @"OK" ]
                                  colors:@[ kGlossyBlackColor ]
                                   block:^(int buttonPressed) {
                                     [_usernameField becomeFirstResponder];
                                   }];
        } else if (error.code == kPFErrorUserEmailTaken) {
          [weakSelf showAlertWithCaption:@"Email address is already in use. Please enter another."
                                  titles:@[ @"OK" ]
                                  colors:@[ kGlossyBlackColor ]
                                   block:^(int buttonPressed) {
                                     [_emailField becomeFirstResponder];
                                   }];
        } else if (error.code == kPFErrorInvalidEmailAddress) {
          [weakSelf showAlertWithCaption:@"Email address is invalid. Please enter another."
                                  titles:@[ @"OK" ]
                                  colors:@[ kGlossyBlackColor ]
                                   block:^(int buttonPressed) {
                                     [_emailField becomeFirstResponder];
                                   }];
        } else {
          [error showParseError:@"signup"];
        }
      }
    }];
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == _usernameField) {
    [_passwordField becomeFirstResponder];
  } else if (textField == _passwordField) {
    [_emailField becomeFirstResponder];
  } else {
    [textField resignFirstResponder];
    [self signup];
  }
  
  return YES;
}

@end
