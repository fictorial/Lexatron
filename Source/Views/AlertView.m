//
//  AlertView.m
//  Lexatron
//
//  Created by Brian Hammond on 8/18/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "AlertView.h"
#import "UIGlossyButton.h"

@interface AlertView ()
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIView *containerView;
@property (nonatomic, copy) AlertBlock alertBlock;
@property (nonatomic, assign) int buttonPressed;
@end

@implementation AlertView

+ (id)alertWithCaption:(NSString *)caption
          buttonTitles:(NSArray *)buttonTitles
          buttonColors:(NSArray *)buttonColors
                 block:(AlertBlock)block
               forView:(UIView *)forView {

  NSParameterAssert(buttonColors.count == buttonTitles.count);

  AlertView *alert = [[AlertView alloc] initWithFrame:forView.bounds
                                                caption:caption
                                           buttonTitles:buttonTitles
                                           buttonColors:buttonColors
                                                  block:block];
  [forView addSubview:alert];
  [alert.containerView slideInFrom:kFTAnimationTop duration:0.4 delegate:nil];
  return alert;
}

- (id)initWithFrame:(CGRect)frame
            caption:(NSString *)caption
       buttonTitles:(NSArray *)buttonTitles
       buttonColors:(NSArray *)buttonColors
              block:(AlertBlock)block {

  self = [super initWithFrame:frame];

  if (self) {
    self.backgroundColor = kAlertCoverColor;

    float margin = SCALED(10);

    float buttonHeight = SCALED(45);
    float buttonWidth = SCALED(100);

    float buttonsWidth = margin + buttonWidth + margin;
    float buttonsHeight = buttonTitles.count * buttonHeight + (buttonTitles.count + 1) * margin;

    float containerWidth = CGRectGetWidth(self.bounds);
    float labelWidth = containerWidth - buttonsWidth - margin;

    UIFont *labelFont = [UIFont fontWithName:kFontName size:kFontSizeHeader];
    CGSize textSize = [caption sizeWithFont:labelFont
                          constrainedToSize:CGSizeMake(labelWidth, CGRectGetHeight(self.bounds))
                              lineBreakMode:UILineBreakModeWordWrap];

    float containerHeight = MAX(margin + textSize.height + margin, buttonsHeight);

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, containerWidth, containerHeight)];
    _containerView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    [_containerView addStandardShadowing];
    [self addSubview:_containerView];

    self.label = [[UILabel alloc] initWithFrame:CGRectMake(margin, margin, labelWidth, MAX(textSize.height, buttonHeight))];
    _label.text = caption;
    _label.backgroundColor = [UIColor clearColor];
    _label.textColor = [UIColor whiteColor];
    _label.numberOfLines = 999;
    _label.lineBreakMode = UILineBreakModeWordWrap;
    _label.shadowColor = [UIColor darkGrayColor];
    _label.shadowOffset = CGSizeMake(0, -1);
    _label.font = labelFont;
    [_containerView addSubview:_label];

    float left = CGRectGetWidth(_containerView.bounds) - margin - buttonWidth;
    __block float top = margin;
    
    [buttonTitles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL *stop) {
      UIGlossyButton *button = [[UIGlossyButton alloc] initWithFrame:CGRectMake(left, top, buttonWidth, buttonHeight)];
      [button setTintColor:[buttonColors objectAtIndex:idx]];
      button.buttonCornerRadius = kGlossyButtonCornerRadius;
      [button setGradientType:kUIGlossyButtonGradientTypeLinearGlossyStandard];
      [button setTitle:title forState:UIControlStateNormal];
      button.titleLabel.font = labelFont;
      button.tag = idx;
      [button addTarget:self action:@selector(doAlertDismissWithButton:) forControlEvents:UIControlEventTouchUpInside];
      [button addStandardShadowing];
      [_containerView addSubview:button];

      top += buttonHeight + margin;
    }];

    self.alertBlock = block;
  }

  return self;
}

- (void)doAlertDismissWithButton:(id)sender {
  self.buttonPressed = [sender tag];

  [_containerView slideOutTo:kFTAnimationTop
                    duration:0.4
                    delegate:self
               startSelector:nil
                stopSelector:@selector(doneSlidingOut:finished:)];
}

- (void)doneSlidingOut:(CAAnimation *)theAnimation finished:(BOOL)finished {
  if (_alertBlock)
    _alertBlock(_buttonPressed);

  [self removeFromSuperview];
}

@end
