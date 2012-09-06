//
//  AppDelegate.m
//  letterquest
//
//  Created by Brian Hammond on 8/1/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "BaseViewController.h"
#import "WelcomeViewController.h"
#import "LQAudioManager.h"
#import "MatchLogic.h"
#import "AuthViewController.h"
#import "LoginViewController.h"
#import "SignupViewController.h"
#import "PushManager.h"
#import "MatchViewController.h"
#import "ActivityViewController.h"
#import "Appirater.h"
#import "iVersion.h"

@implementation AppDelegate {
  UINavigationController *_navigationController;
}

+ (void)initialize {
  [iVersion sharedInstance].appStoreID = [kAppStoreAppID integerValue];
  [iVersion sharedInstance].remoteVersionsPlistURL = @"http://fictorial.com/lexatron/versions.plist";
}

- (void)setupTestFlight {
#ifndef APPSTORE
  
  // Only use UDID (which is deprecated) when testing not for distribution.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [TestFlight setDeviceIdentifier:[[UIDevice currentDevice] uniqueIdentifier]];
#pragma clang diagnostic pop
  
#endif

  // The UDID stuff above MUST come before takeOff or else all the logs on TF will be from "Anonymous User"
  // http://stackoverflow.com/questions/10939491/testers-all-show-up-as-anonymous-user

  [TestFlight takeOff:@"d06e6c2314c6cd3a1cce640740a7ecac_OTA2NTkyMDEyLTA1LTE2IDAwOjA0OjI5LjAxNzEzNg"];
}

- (void)setupParse {
#if ADHOC || APPSTORE
  // The app on Parse has been configured to use a production SSL certificate for push notifications.
  // This is required for Ad Hoc and obviously for App Store builds.
  // https://parse.com/apps/lexatron-prod

  [Parse setApplicationId:@"5WcUeWwrin0PM46XWR8ODj5chxYk6Mm7QZs8f1BX"
                clientKey:@"ZoNGwxDzerOCf38zGaX26IQhH6B8woOpWmFAHCbW"];

#else  // DEBUG

  // https://parse.com/apps/lexatron-dev

  [Parse setApplicationId:@"a0142efFhptyzQFQGARMGB3rzWvMzGBGaisu9Dix"
                clientKey:@"OPSDKtPAxJNP7O6266GtwH2JKlklm8sJe43v8Uz5"];

#endif

  [PFFacebookUtils initializeWithApplicationId:@"356852647713029"];

  [PFTwitterUtils initializeWithConsumerKey:@"7Cxdht8ZGhLCsqR4hKPgbQ"
                             consumerSecret:@"2V9wKDrvqEGHhUfWS7ACr1uXvfeC5zDjvXbxGAAygRY"];

#if DEBUG || ADHOC
  PFUser *currentUser = [PFUser currentUser];
  DLog(@"current user: %@", currentUser.username);
#endif
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self setupTestFlight];
  [self setupParse];

  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor blackColor];
  UIViewController *firstVC = [PFUser currentUser] ? [ActivityViewController controller] : [WelcomeViewController controller];
  _navigationController = [[UINavigationController alloc] initWithRootViewController:firstVC];
  _navigationController.navigationBarHidden = YES;
  self.window.rootViewController = _navigationController;  
  [self.window makeKeyAndVisible];

  // Load word list now ahead of time so there's no delay when playing a match.

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    [WordList sharedWordList];
  });

  [LQAudioManager sharedManager];  // just access to init
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin:) name:kLoginNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSignup:) name:kSignupNotification object:nil];

  [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge|
                                                   UIRemoteNotificationTypeAlert|
                                                   UIRemoteNotificationTypeSound)];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(turnDidHappen:) name:kTurnDidEndNotification object:nil];  // local
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(turnDidHappen:) name:kPushNotificationHandledNotification object:nil];  // remote

  NSDictionary *pushInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
  if (pushInfo) {
    DLog(@"app launched due to receipt of a push notification; handling...");
    [self performBlock:^(id sender) {
      [[PushManager sharedManager] handleInboundPush:pushInfo];
    } afterDelay:2];
  }

  // Show any pass-and-play match that was active the last time the app was terminated.

  Match *resumablePassAndPlayMatch = [Match resumablePassAndPlayMatch];
  if (resumablePassAndPlayMatch) {
    MatchViewController *vc = [MatchViewController controllerWithMatch:resumablePassAndPlayMatch];
    [_navigationController pushViewController:vc animated:NO];
  }

  [Appirater appLaunched:NO];

  return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  [Appirater appEnteredForeground:NO];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)replaceTopViewControllerForMatch:(Match *)match {
  [_navigationController popViewControllerAnimated:NO];
  MatchViewController *vc = [MatchViewController controllerWithMatch:match];
  [_navigationController pushViewController:vc animated:NO];
}

- (void)loadPassAndPlayMatch {
  PFUser *player1 = [PFUser user];
  player1.username = NSLocalizedString(@"Player1", @"Name of first player for pass-and-play matches");

  PFUser *player2 = [PFUser user];
  player2.username = NSLocalizedString(@"Player2", @"Name of first player for pass-and-play matches");

  Match *aMatch = [[Match alloc] initWithPlayer:player1 player:player2];
  aMatch.passAndPlay = YES;

  MatchViewController *vc = [MatchViewController controllerWithMatch:aMatch];
  [_navigationController pushViewController:vc animated:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  DLog(@"app became active: current user = %@", [PFUser currentUser]);

  [self extendFacebookToken];
  [self refreshAppIconBadge];
}

#pragma mark - user

- (PFUser *)requireLoggedInUser {
  PFUser *currentUser = [PFUser currentUser];
  
  DLog(@"current user: %@", currentUser.username);
  
  if (currentUser && currentUser.isAuthenticated)
    return currentUser;
    
  // No previous session; login the user. This will give an option to sign up.

  AuthViewController *vc = [AuthViewController controller];
  [_navigationController pushViewController:vc animated:NO];

  return nil;
}

- (void)didLogin:(NSNotification *)notification {
  [[PushManager sharedManager] subscribeToCurrentUserChannel];
  [self updateAppIconBadgeTo:0];
}

- (void)didSignup:(NSNotification *)notification {
  PFUser *user = [PFUser currentUser];

  if ([PFFacebookUtils isLinkedWithUser:user]) {
    DLog(@"linked with fb");

    if (user.isNew) {
      DLog(@"user created an account by logging in through facebook");

      [user setObject:[NSNumber numberWithBool:YES] forKey:@"loginViaFB"];
      [[PFFacebookUtils facebook] requestWithGraphPath:@"me" andDelegate:self];
    } else {
      [self extendFacebookToken];
    }
  } else {
    DLog(@"not linked with fb");
  }

  [self updateAppIconBadgeTo:0];
}

#pragma mark - facebook

- (void)extendFacebookToken {
  [PFFacebookUtils extendAccessTokenIfNeededForUser:[PFUser currentUser] block:^(BOOL succeeded, NSError *error) {}];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {

  return [PFFacebookUtils handleOpenURL:url];
}

// Called when Facebook returns information about the user that logged in via Facebook
// (which creates a new user).

- (void)request:(PF_FBRequest *)request didLoad:(id)result {
  DLog(@"got fb id & name for current user: %@, %@",
       [result objectForKey:@"id"],
       [result objectForKey:@"name"]);

  [[PFUser currentUser] setObject:[result objectForKey:@"id"] forKey:@"fbId"];
  [[PFUser currentUser] setObject:[result objectForKey:@"name"] forKey:@"displayName"];

  [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"finalize logging in via Facebook", nil)];

      // Completely give up on the signup process through facebook-login.

      [PFUser logOut];
      [[PFUser currentUser] deleteEventually];

      [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
      [(UINavigationController *)self.window.rootViewController popToRootViewControllerAnimated:YES];
    } else {
      [[PushManager sharedManager] subscribeToCurrentUserChannel];
    }
  }];
}

- (void)request:(PF_FBRequest *)request didFailWithError:(NSError *)error {
  [error showParseError:NSLocalizedString(@"fetch account info", nil)];

  // Completely give up on the signup process through facebook-login.

  [PFUser logOut];
  [[PFUser currentUser] deleteEventually];

  [self.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
  [(UINavigationController *)self.window.rootViewController popToRootViewControllerAnimated:YES];
}

#pragma mark - push notifications

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {
  [TestFlight passCheckpoint:@"pushEnabled"];

  [[PushManager sharedManager] setupWithToken:newDeviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  [TestFlight passCheckpoint:@"pushDisabled"];

  if ([error code] == 3010) {
    DLog(@"Push notifications don't work in the simulator!");
  } else {
    DLog(@"didFailToRegisterForRemoteNotificationsWithError: %@", error);
  }

  [[PushManager sharedManager] setupWithToken:nil];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
  [TestFlight passCheckpoint:@"pushReceived"];

  [[PushManager sharedManager] handleInboundPush:userInfo];
}

#pragma mark - app icon badge

- (void)turnDidHappen:(NSNotification *)notification {
  Match *match = [notification.userInfo objectForKey:@"match"];

  if (match.passAndPlay)
    return;

#if APPSTORE

  if (match.state == kMatchStateEndedNormal && match.winningPlayer == [match currentUserPlayerNumber]) {
    DLog(@"local player won the match -- notifying appirater of this SIGNIFICANT event");

    [self performBlock:^(id sender) {
      [Appirater userDidSignificantEvent:YES];
    } afterDelay:2];
  }

#endif

  [self refreshAppIconBadge];
}

- (void)updateAppIconBadgeTo:(int)count {
  DLog(@"count of actionable matches: %d", count);

  [UIApplication sharedApplication].applicationIconBadgeNumber = count;
}

- (void)refreshAppIconBadge {
  [self updateAppIconBadgeTo:0];

  __weak id weakSelf = self;
  [[PFUser currentUser] countOfActionableMatches:^(int number, NSError *error) {
    if (error) {
      DLog(@"failed to get count of actionable matches:%@", error);
      [weakSelf updateAppIconBadgeTo:0];
      return;
    }

    [weakSelf updateAppIconBadgeTo:number];
  }];
}

@end
