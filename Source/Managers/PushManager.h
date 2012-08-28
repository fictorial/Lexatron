//
//  PushManager.h
//  WordGame
//
//  Created by Brian Hammond on 6/29/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kPushNotificationHandledNotification;

// Listens for turn-ended notifications posted by Match objects in this app and sends push notifications to the opponent as needed.
// Also, handles inbound/received push notifications (as routed through AppDelegate).

@interface PushManager : NSObject

+ (PushManager *)sharedManager;

// from AppDelegate:
- (void)setupWithToken:(NSData *)token;
- (BOOL)handleInboundPush:(NSDictionary *)userInfo;

// Handles cases where user logs in/out during session
- (void)subscribeToCurrentUserChannel;
- (void)unsubscribeFromCurrentUserChannel;

@end
