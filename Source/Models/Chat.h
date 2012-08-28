//
//  Chat.h
//  Lexatron
//
//  Created by Brian Hammond on 8/26/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Match.h"

@class Chat;

@protocol ChatDelegate <NSObject>

- (void)didFailToLoadDataInChat:(Chat *)chat
                          error:(NSError *)error;

- (void)didLoadMessages:(NSArray *)messages
                   chat:(Chat *)chat
              hasUnread:(BOOL)currentUserHasUnreadMessages;

- (void)willPostMessage:(NSString *)message
                   chat:(Chat *)chat;

- (void)didPostMessage:(NSString *)message
                  chat:(Chat *)chat;

@end

@interface ChatMessage : NSObject
@property (nonatomic, strong) PFUser *who;
@property (nonatomic, strong) NSString *what;
@property (nonatomic, strong) NSDate *when;
@end

@interface Chat : NSObject

@property (nonatomic, strong, readonly) Match *match;
@property (nonatomic, strong, readonly) NSArray *messages;

+ (id)chatWithMatch:(Match *)match delegate:(id<ChatDelegate>)delegate;
- (void)postMessage:(NSString *)message;
- (void)refresh;
- (void)markAllAsRead;

@end
