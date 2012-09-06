//
//  HelpViewController.m
//  Lexatron
//
//  Created by Brian Hammond on 8/15/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "HelpViewController.h"

@interface HelpViewController ()
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIWebView *webView;
@end

@implementation HelpViewController

- (void)loadView {
  [super loadView];

  float w = self.view.bounds.size.width;
  float h = self.view.bounds.size.height;

  float cw = w * 3/4.;
  float margin = SCALED(14);

  self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cw, h - margin*2)];
  _containerView.center = CGPointMake(w/2, h/2);
  _containerView.backgroundColor = [self bgColor];
  _containerView.layer.cornerRadius = 10;
  _containerView.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.4].CGColor;
  _containerView.layer.borderWidth = 1;
  _containerView.clipsToBounds = YES;
  [self.view addSubview:_containerView];

  float webViewMargin = margin/2;
  float width = cw-webViewMargin*2;
  CGRect webViewFrame = CGRectMake(cw/2 - width/2, webViewMargin, width, CGRectGetHeight(_containerView.bounds) - webViewMargin*2);
  self.webView = [[UIWebView alloc] initWithFrame:webViewFrame];
  _webView.delegate = self;
  _webView.backgroundColor = [UIColor clearColor];
  _webView.opaque = NO;
  [self hideGradientBackground:_webView];

  NSString *path = [[NSBundle mainBundle] bundlePath];
  NSString *html = [NSString stringWithContentsOfFile:[path stringByAppendingPathComponent:@"shorthelp.html"]
                                             encoding:NSUTF8StringEncoding
                                                error:nil];
  NSURL *baseURL = [NSURL fileURLWithPath:path];
  [_webView loadHTMLString:html baseURL:baseURL];
  [_containerView addSubview:_webView];
}

- (UIColor *)bgColor {
//  return [UIColor colorWithWhite:0 alpha:0.85];
  return [UIColor colorWithWhite:0.90 alpha:0.90];
}

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
  return YES;
}

- (void) hideGradientBackground:(UIView*)theView {
  for (UIView * subview in theView.subviews) {
    if ([subview isKindOfClass:[UIImageView class]])
      subview.hidden = YES;
    [self hideGradientBackground:subview];
  }
}

- (BOOL)shouldShowSettingsButton {
  return NO;
}
@end
