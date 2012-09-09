//
//  BaseViewController.h
//  letterquest
//
//  Created by Brian Hammond on 8/1/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AlertView.h"

@interface BaseViewController : UIViewController

@property (nonatomic, assign) BOOL requiresAuthenticatedUser;


- (void)showHUDWithActivity:(BOOL)activity
                    caption:(NSString *)caption;

- (void)showActivityHUD;
- (void)hideActivityHUD;

// By default, the HUD is modal in that it blocks all user interaction with its superview.

- (void)makeHUDNonModal;

@property (nonatomic, assign, readonly) BOOL isShowingHUD;


+ (id)controller;

- (UIButton *)makeButtonWithTitle:(NSString *)title
                            color:(UIColor *)color
                         selector:(SEL)selector;

- (UIButton *)addButtonWithTitle:(NSString *)title
                           color:(UIColor *)color
                        selector:(SEL)selector
                          center:(CGPoint)centerPoint;

- (BOOL)shouldDisplayBackgroundBoardImage;
- (BOOL)shouldShowSettingsButton;

- (void)goBack;

- (void)playButtonSound:(id)sender;

- (void)showAlertWithCaption:(NSString *)caption titles:(NSArray *)titles colors:(NSArray *)colors block:(AlertBlock)block;
- (void)showNoticeAlertWithCaption:(NSString *)caption;
- (void)showConfirmAlertWithCaption:(NSString *)caption block:(AlertBlock)block;
- (void)showActionableAlertWithCaption:(NSString *)caption block:(AlertBlock)block;
- (void)hideAllAlerts;
- (BOOL)isShowingAlert;

- (void)startTimeoutTimer;
- (void)removeTimeoutTimer;
- (void)handleTimeout:(id)sender;

@end