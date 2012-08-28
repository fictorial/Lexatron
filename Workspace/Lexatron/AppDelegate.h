//
//  AppDelegate.h
//  letterquest
//
//  Created by Brian Hammond on 8/1/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Match;

@interface AppDelegate : UIResponder <UIApplicationDelegate, PF_FBRequestDelegate>

- (PFUser *)requireLoggedInUser;

@property (strong, nonatomic) UIWindow *window;

- (void)replaceTopViewControllerForMatch:(Match *)match;
- (void)loadPassAndPlayMatch;

@end
