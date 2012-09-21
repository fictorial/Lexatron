//
//  PromptViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "PromptViewController.h"

@interface PromptViewController ()
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, copy) PromptCallback callback;
@property (nonatomic, strong) UITextField *textField;
@end

@implementation PromptViewController

+ (id)controllerWithPrompt:(NSString *)prompt
               placeholder:(NSString *)placeholder
                  callback:(PromptCallback)callback {

  PromptViewController *vc = [PromptViewController controller];
  vc.title = prompt;
  vc.callback = callback;
  return vc;
}

- (void)loadView {
  [super loadView];

  self.textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, SCALED(200), SCALED(30))];
  _textField.center = CGPointMake(self.view.bounds.size.width/2, SCALED(60));
  _textField.backgroundColor = [UIColor whiteColor];
  _textField.delegate = self;
  _textField.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  _textField.placeholder = _placeholder;
  _textField.returnKeyType = UIReturnKeyGo;
  _textField.borderStyle = UITextBorderStyleRoundedRect;
  _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  _textField.spellCheckingType = UITextSpellCheckingTypeNo;
  _textField.autocorrectionType = UITextAutocorrectionTypeNo;
  _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
  [self.view addSubview:_textField];

  float w = self.view.bounds.size.width;
  float margin = SCALED(10);

  [self addButtonWithTitle:@"OK"
                     color:kGlossyGreenColor
                  selector:@selector(doSubmit:)
                    center:CGPointMake(w/2, CGRectGetMaxY(_textField.frame) + kGlossyButtonHeight/2+margin)];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_textField becomeFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (_callback)
    _callback(textField.text);
  return YES;
}

- (void)doSubmit:(id)sender {
  if (_callback)
    _callback(_textField.text);
}

@end
