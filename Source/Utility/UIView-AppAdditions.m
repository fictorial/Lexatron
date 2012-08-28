#import "UIView-AppAdditions.h"
#import "CMPopTipView.h"

@implementation UIView (AppAdditions)

- (void)showErrorTip:(NSString *)message {
  CMPopTipView *errorView = [[CMPopTipView alloc] initWithMessage:message];
  errorView.backgroundColor = [UIColor redColor];
  errorView.textColor = [UIColor whiteColor];
  errorView.textFont = [UIFont fontWithName:kFontName size:kFontSizeHUD];
  [errorView presentPointingAtView:self inView:self.superview animated:YES];
  
  [self performBlock:^(id sender) {
    [errorView dismissAnimated:YES];
    [self becomeFirstResponder];
  } afterDelay:3];       
}

- (void)updateButtonBorderWidths:(BOOL)large {
  for (UIView *subview in self.subviews) {
    if ([subview isKindOfClass:[UIButton class]]) {
      UIButton *button = (UIButton *)subview;
      NSString *text = [button titleForState:UIControlStateNormal];
      if (text) {
        button.layer.borderWidth = large ? 3 : 1;
      }
    }
  }
}

- (void)addStandardShadowing {
  self.layer.shadowColor = [UIColor blackColor].CGColor;
  self.layer.shadowOffset = CGSizeMake(0, SCALED(1));
  self.layer.shadowOpacity = 0.35;
  self.layer.shadowRadius = SCALED(1);
}

@end
