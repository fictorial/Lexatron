//
//  PushManager.m
//  WordGame
//
//  Created by Brian Hammond on 6/29/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "PushManager.h"
#import "MatchLogic.h"
#import "MatchViewController.h"
#import "SignupViewController.h"

#import "ATMHud.h"
#import "ATMHudView.h"

static NSString * const kPushTypeChallenge = @"challenge";
static NSString * const kPushTypeTurn = @"turn";
static NSString * const kPushTypeEnded = @"ended";

NSString * const kPushNotificationHandledNotification = @"PushNotificationHandledNotification";

@implementation PushManager {
  BOOL _hasDeviceToken;
}

#pragma mark - setup

+ (PushManager *)sharedManager {
#if TARGET_IPHONE_SIMULATOR
  return nil;
#endif

  static dispatch_once_t once;
  static id sharedInstance;
  
  dispatch_once(&once, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (void)setupWithToken:(NSData *)token {
  DLog(@"setting up...");
  
  if (token) {
    _hasDeviceToken = YES;
    [PFPush storeDeviceToken:token];

    [PFPush subscribeToChannelInBackground:@""];  // global broadcasts
    [self subscribeToCurrentUserChannel];

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(turnDidEnd:)
     name:kTurnDidEndNotification
     object:nil];

    DLog(@"listening to %@", kTurnDidEndNotification);
  }
}

- (void)subscribeToCurrentUserChannel { 
  DLog(@"trying to subscribe to current user's push channel");
  
  if ([PFUser currentUser]) {
    NSString *channelName = [[PFUser currentUser] pushChannelName];

    // It's possible to login as one user, subscribe to their channel, then delete the app,
    // reinstall, then login as another user... and get both user's pushes.  Ugh.
    // Thus, unsubscribe from all channels other than the current logged-in user's channel
    // and the global broadcast channel.

    [[[[PFInstallation currentInstallation] channels] select:^BOOL(NSString *channel) {
      return ![channel isEqualToString:@""] && ![channel isEqualToString:channelName];
    }] each:^(NSString *channel) {
      DLog(@"oops, subscribed to some other channel %@ ... unsubscribing", channel);
      [PFPush unsubscribeFromChannelInBackground:channel];
    }];

    DLog(@"subscribing to %@", channelName);
  
    [PFPush subscribeToChannelInBackground:channelName block:^(BOOL succeeded, NSError *error) {
      if (!succeeded) {
        UINavigationController *nav = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
        id vc = nav.presentedViewController ? nav.presentedViewController : nav.topViewController;
        if ([vc isKindOfClass:BaseViewController.class]) {
          BaseViewController *baseVC = (BaseViewController *)vc;
          [baseVC showNoticeAlertWithCaption:@"Failed to subscribe to notifications channel. Notifications might not be received during this session."];
        }
      } else {
        DLog(@"subscribed to push channel %@ for user %@ with objectId %@", 
             channelName, [[PFUser currentUser] usernameForDisplay], [PFUser currentUser].objectId);
      }
    }];
  }
}

- (void)unsubscribeFromCurrentUserChannel {
  NSString *channelName = [[PFUser currentUser] pushChannelName];
  DLog(@"unsubscribing from push channel %@", channelName);
  [PFPush unsubscribeFromChannelInBackground:channelName]; 
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - outbound notifications

// Turn ended in a local match due to local player / current user action.
// Maybe send a push notification to the opponent about this action.

- (void)turnDidEnd:(NSNotification *)notification {
  DLog(@"got turn-did-end notification");
  
  Match *match = [notification.userInfo objectForKey:@"match"];
  
  if (match.passAndPlay)
    return;

  __weak id weakSelf = self;

  PFUser *opponent = [match opponentPlayer];

  if ([opponent blocks:[PFUser currentUser]]) {
    DLog(@"opponent blocks current user so not sending push notification");
    return;
  }
    
  // We have to set the badge to an absolute value each time we push.
  // There's no place that maintains a count per APS device token ...
  
  [opponent countOfActionableMatches:^(int badgeCount, NSError *error) {
    if (error) {
      DLog(@"error: %@", [error localizedDescription]);
      return;
    }

    DLog(@"opponent has %d actionable matches (app icon badge value)", badgeCount);
    
    if (match.state == kMatchStatePending) {
      [self sendChallengePushTo:opponent badgeCount:badgeCount matchID:[match matchID]];
      return;
    }
    
    if (match.state == kMatchStateEndedNormal || match.state == kMatchStateEndedResign || match.state == kMatchStateEndedTimeout) {
      BOOL opponentWon = match.winningPlayer == [match opponentPlayerNumber];
      [weakSelf sendMatchEndedPushTo:opponent badgeCount:badgeCount won:opponentWon matchID:[match matchID]];
      return;
    }
    
    if (match.state == kMatchStateActive) {
      [weakSelf sendYourTurnPushTo:opponent badgeCount:badgeCount matchID:[match matchID]];
    }
  }];
}

- (void)sendChallengePushTo:(PFUser *)opponent badgeCount:(int)badgeCount matchID:(NSString *)matchID {
  PFUser *localUser = [PFUser currentUser];

  DLog(@"sending a match-challenge push from %@ to %@ on channel %@",
        [localUser usernameForDisplay], [opponent usernameForDisplay], [opponent pushChannelName]);
  
  NSString *format = NSLocalizedString(@"%@ challenged you to a match!",
                                       @"%@ is the username of the requesting player");
  
  NSString *displayName = [localUser usernameForDisplay];
  
  NSString *alert = [NSString stringWithFormat:format, displayName];

  NSDictionary *payload = @{
  @"alert": alert,
  @"badge": @(badgeCount),
  @"pushType": kPushTypeChallenge,
  @"opponentID": localUser.objectId,
  @"opponent": displayName,
  @"matchID": matchID
  };

  PFPush *push = [PFPush new];
  [push setPushToAndroid:NO];
  [push setChannel:[opponent pushChannelName]];
  [push expireAfterTimeInterval:86400];
  [push setData:payload];
  [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"notify opponent", nil)];
    } else {
      DLog(@"sent a match-challenge push from %@ to %@",
            [localUser usernameForDisplay], [opponent usernameForDisplay]);
    }
  }];
}

- (void)sendMatchEndedPushTo:(PFUser *)opponent 
                  badgeCount:(int)badgeCount
                         won:(BOOL)opponentWon
                     matchID:(NSString *)matchID {
  
  PFUser *localUser = [PFUser currentUser];
  
  DLog(@"sending a match-ended push from %@ to %@ on channel %@", 
        [localUser usernameForDisplay], [opponent usernameForDisplay], [opponent pushChannelName]);
  
  NSString *format;
  
  if (opponentWon) {
    format = NSLocalizedString(@"You won vs %@!",
                               @"%@ is the username of the other player");
  } else {
    format = NSLocalizedString(@"%@ won a match with you.",
                               @"%@ is the username of the other player");
  }
  
  NSString *displayName = [localUser usernameForDisplay];
 
  NSString *alert = [NSString stringWithFormat:format, displayName];

  NSDictionary *payload = @{
  @"alert": alert,
  @"badge": @(badgeCount),
  @"pushType": kPushTypeEnded,
  @"otherPlayerID": localUser.objectId,
  @"otherPlayer": displayName,
  @"matchID": matchID
  };

  PFPush *push = [PFPush new];
  [push setPushToAndroid:NO];
  [push setChannel:[opponent pushChannelName]];
  [push expireAfterTimeInterval:86400];
  [push setData:payload];
  [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"notify opponent", nil)];
    } else {
      DLog(@"sent a match-ended push from %@ to %@",
            [localUser usernameForDisplay], [opponent usernameForDisplay]);
    }
  }];
}

- (void)sendYourTurnPushTo:(PFUser *)opponent 
                badgeCount:(int)badgeCount 
                   matchID:(NSString *)matchID {
  
  PFUser *localUser = [PFUser currentUser];
  
  DLog(@"sending a your-turn push from %@ to %@ on channel %@",
        [localUser usernameForDisplay], [opponent usernameForDisplay], [opponent pushChannelName]);

  NSString *format = NSLocalizedString(@"It's your turn vs. %@!",
                                       @"%@ is the username of the other player");
  
  NSString *displayName = [localUser usernameForDisplay];
  
  NSString *alert = [NSString stringWithFormat:format, displayName];

  NSDictionary *payload = @{
  @"alert": alert,
  @"badge": @(badgeCount),
  @"pushType": kPushTypeTurn,
  @"opponentID": localUser.objectId,
  @"opponent": displayName,
  @"matchID": matchID
  };

  PFPush *push = [PFPush new];
  [push setPushToAndroid:NO];
  [push setChannel:[opponent pushChannelName]];
  [push expireAfterTimeInterval:86400];
  [push setData:payload];
  [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"notify opponent", nil)];
    } else {
      DLog(@"sent a your-turn push from %@ to %@", 
            [localUser usernameForDisplay], [opponent usernameForDisplay]);
    }
  }];
}

#pragma mark - inbound notifications

- (void)handleInboundPushUserInfo:(NSDictionary *)userInfo
                       alertTitle:(NSString *)title
                cancelButtonTitle:(NSString *)cancelButtonTitle
                    okButtonTitle:(NSString *)okButtonTitle
                 otherButtonTitle:(NSString *)otherButtonTitle
                      cancelBlock:(void(^)())cancelBlock
                       otherBlock:(void(^)())otherBlock {

  NSString *pushType = [userInfo objectForKey:@"pushType"];
  NSString *alert = [userInfo valueForKeyPath:@"aps.alert"];
  NSString *matchID = [userInfo objectForKey:@"matchID"];
  NSString *opponent = [userInfo objectForKey:@"opponent"];
  NSString *opponentID = [userInfo objectForKey:@"opponentID"];
  
  DLog(@"%@ from %@ (%@) match=%@ alert=%@", pushType, opponent, opponentID, matchID, alert);
  
  __weak id weakSelf = self;

  NSArray *titles, *colors;
  if (otherButtonTitle) {
    titles = @[ cancelButtonTitle, okButtonTitle, otherButtonTitle ];
    colors = @[ kGlossyRedColor, kGlossyGreenColor, kGlossyBlackColor ];
  } else {
    titles = @[ cancelButtonTitle, okButtonTitle ];
    colors = @[ kGlossyBlackColor, kGlossyGreenColor ];
  }

  BaseViewController *topBaseVC = [self getTopBaseViewControllerIfAny];
  [topBaseVC
   showAlertWithCaption:alert
   titles:titles
   colors:colors
   block:^(int buttonPressed) {
     [[NSNotificationCenter defaultCenter] postNotificationName:kPushNotificationHandledNotification object:nil];

     if (buttonPressed == 0) {  // cancel
       DLog(@"%@ canceled/rejected/declined", pushType);
       if (cancelBlock) cancelBlock();
     } else if (buttonPressed == 1) {  // ok
       DLog(@"%@ will play", pushType);
       BOOL alreadyViewingThisMatch = [self currentlyViewingMatchWithID:[userInfo objectForKey:@"matchID"]];
       [weakSelf fetchAndShowMatchWithMatchID:matchID viewingThisMatchAlready:alreadyViewingThisMatch];
     } else if (buttonPressed == 2) {  // other
       DLog(@"%@ selected other (%@)", pushType, otherButtonTitle);
       if (otherBlock) otherBlock();
     }
   }];
}

- (BOOL)handleInboundPush:(NSDictionary *)userInfo {
  DLog(@"trying to handle push notification: %@", userInfo);

  BaseViewController *topBaseVC = [self getTopBaseViewControllerIfAny];
  if ([topBaseVC isKindOfClass:MatchViewController.class]) {
    MatchViewController *matchVC = (MatchViewController *)topBaseVC;
    Match *match = matchVC.match;
    if (match.turns.count == 0) {
      DLog(@"not showing alert since playing first turn in a match");
      return YES;
    }
  }

  NSString *pushType = [userInfo objectForKey:@"pushType"];
  
  if ([pushType isEqualToString:kPushTypeChallenge]) {
    BaseViewController *topBaseVC = [self getTopBaseViewControllerIfAny];
    
    if ([topBaseVC isKindOfClass:MatchViewController.class]) {
      MatchViewController *matchVC = (MatchViewController *)topBaseVC;
      Match *match = matchVC.match;

      if (match.currentUserIsCurrentPlayer) {
        DLog(@"not showing challenge now since user is viewing match in which it is their turn currently... would be annoying to be interrupted for a new match challenge here.");
        return NO;
      }
    }

    if (topBaseVC && [topBaseVC isShowingAlert]) {
      DLog(@"not showing challenge now since user has alert open already");
      return NO;
    }

    __weak id weakSelf = self;

    [self handleInboundPushUserInfo:userInfo
                         alertTitle:NSLocalizedString(@"Challenge", nil)
                  cancelButtonTitle:NSLocalizedString(@"Reject", nil)
                      okButtonTitle:NSLocalizedString(@"Accept", nil)
                   otherButtonTitle:NSLocalizedString(@"Later", nil)
                        cancelBlock:^{
                          [weakSelf declineMatchChallenge:userInfo];
                        }
                         otherBlock:^{
                           // just close the alert
                         }];
  } else if ([pushType isEqualToString:kPushTypeTurn]) {
    if ([self currentlyViewingMatchWithID:[userInfo objectForKey:@"matchID"]]) {
      // Skip the alert and just "refresh" the match
      [self fetchAndShowMatchWithMatchID:[userInfo objectForKey:@"matchID"] viewingThisMatchAlready:YES];
    } else {    
      [self handleInboundPushUserInfo:userInfo
                           alertTitle:NSLocalizedString(@"Your Turn", nil)
                    cancelButtonTitle:NSLocalizedString(@"Later", nil)
                        okButtonTitle:NSLocalizedString(@"Play", nil)
                     otherButtonTitle:nil cancelBlock:nil otherBlock:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kPushNotificationHandledNotification object:nil];
  } else if ([pushType isEqualToString:kPushTypeEnded]) {
    if ([self currentlyViewingMatchWithID:[userInfo objectForKey:@"matchID"]]) {
      // Skip the alert and just "refresh" the match
      [self fetchAndShowMatchWithMatchID:[userInfo objectForKey:@"matchID"] viewingThisMatchAlready:YES];
    } else {    
      [self handleInboundPushUserInfo:userInfo
                           alertTitle:NSLocalizedString(@"Match Ended", nil)
                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                        okButtonTitle:NSLocalizedString(@"View", nil)
                     otherButtonTitle:nil cancelBlock:nil otherBlock:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kPushNotificationHandledNotification object:nil];
  } else {
    DLog(@"don't know how to handle this push notification type; ignoring!");
    return NO;
  }
  
  return YES;
}

- (BaseViewController *)getTopBaseViewControllerIfAny {
  if ([[UIApplication sharedApplication].keyWindow.rootViewController isKindOfClass:UINavigationController.class]) {
    UINavigationController *nav = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
    if ([nav.topViewController isKindOfClass:BaseViewController.class]) {
      BaseViewController *baseVC = (BaseViewController *)nav.topViewController;
      return baseVC;
    }
  }
  return nil;
}

- (void)declineMatchChallenge:(NSDictionary *)userInfo {
  NSString *matchID = [userInfo objectForKey:@"matchID"];

  PFQuery *query = [PFQuery queryWithClassName:@"Match"];
  
  [query getObjectInBackgroundWithId:matchID block:^(PFObject *object, NSError *error) {
    if (error)
      return;

    [Match matchWithExistingMatchObject:object block:^(Match *aMatch, NSError *error) {
      if (error)
        return;
      
      [aMatch decline];
    }];
  }];
}

- (BOOL)currentlyViewingMatchWithID:(NSString *)matchID {
  id nav = [UIApplication sharedApplication].keyWindow.rootViewController;
  
  MatchViewController *matchVC = nil;
  
  if ([[nav topViewController] isKindOfClass:[MatchViewController class]])
    matchVC = (MatchViewController *)[nav topViewController];
  
  Match *match = matchVC.match;

  DLog(@"checking if viewing match referenced in push notification: notification=%@ current=%@", matchID, [match matchID]);
  
  return !match.passAndPlay && [[match matchID] isEqualToString:matchID];
}

- (void)removeHUDs {
  [[UIApplication sharedApplication].keyWindow.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([obj isKindOfClass:[ATMHudView class]])
      [obj removeFromSuperview];
  }];
}

- (void)handleTimeout:(id)sender {
  [self removeHUDs];
  [[self getTopBaseViewControllerIfAny] showNoticeAlertWithCaption:@"Network problems? Please try again later!"];
}

- (void)fetchAndShowMatchWithMatchID:(NSString *)matchID viewingThisMatchAlready:(BOOL)viewingThisMatchAlready {
  DLog(@"fetching match info for match with id %@", matchID);

  [self removeHUDs];

  ATMHud *hud = [ATMHud new];
  [hud setActivity:YES];
  [hud setActivityStyle:UIActivityIndicatorViewStyleWhiteLarge];
  [[UIApplication sharedApplication].keyWindow addSubview:hud.view];
  [hud show];
  
  __weak id weakHud = hud;
  __weak id weakSelf = self;
  __weak id weakNav = [UIApplication sharedApplication].keyWindow.rootViewController;
  
  // Load the match from the backend and then show a view controller for the match.

  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kNetworkTimeoutDuration
                                                    target:self
                                                  selector:@selector(handleTimeout:)
                                                  userInfo:nil
                                                   repeats:NO];

  PFQuery *query = [PFQuery queryWithClassName:@"Match"];

  [query getObjectInBackgroundWithId:matchID block:^(PFObject *object, NSError *error) {
    [timer invalidate];
    [weakHud hide];
    
    [weakSelf performBlock:^(id sender) {
      [[weakHud view] removeFromSuperview];
    } afterDelay:0.2];
    
    if (error) {
      [error showParseError:NSLocalizedString(@"fetch match info", @"Activity indicator")];
      return;
    }
    
    DLog(@"fetched match object OK from backend; showing match VC...");
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kNetworkTimeoutDuration
                                                      target:self
                                                    selector:@selector(handleTimeout:)
                                                    userInfo:nil
                                                     repeats:NO];

    [Match matchWithExistingMatchObject:object block:^(Match *aMatch, NSError *error) {
      [timer invalidate];

      if (error) {
        [error showParseError:NSLocalizedString(@"fetch match info", @"Activity indicator")];
      } else {
        DLog(@"already viewing this match? %d", viewingThisMatchAlready);
        
        // Just remove any match VC at the top and replace with one for this match
        
        if ([[weakNav topViewController] isKindOfClass:[MatchViewController class]]) {
          DLog(@"pop existing match vc");
          [weakNav popViewControllerAnimated:NO];
        }
        
        MatchViewController *vc = [MatchViewController controllerWithMatch:aMatch];
        vc.hasAcceptedChallenge = YES;
        [weakNav pushViewController:vc animated:NO];
      }
    }];
  }];
}

@end
