//
//  Chat.m
//  Lexatron
//
//  Created by Brian Hammond on 8/26/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "Chat.h"
#import "Match.h"

@implementation ChatMessage
@end

@interface Chat ()
@property (nonatomic, strong) PFObject *chatObject;
@property (nonatomic, strong, readwrite) Match *match;
@property (nonatomic, weak) id<ChatDelegate> delegate;
@property (nonatomic, strong, readwrite) NSArray *messages;
@end

@implementation Chat

+ (id)chatWithMatch:(Match *)match delegate:(id<ChatDelegate>)aDelegate {
  NSParameterAssert(match);
  NSParameterAssert(match.matchID);
  NSParameterAssert(!match.passAndPlay);

  Chat *chat = [Chat new];
  chat.match = match;
  chat.delegate = aDelegate;
  [chat loadChatObject];
  return chat;
}

- (void)loadChatObject {
  __weak id weakSelf = self;

  PFQuery *query = [PFQuery queryWithClassName:@"Chat"];
  [query whereKey:@"parent" equalTo:_match.matchID];

  DLog(@"loading chat for match %@", _match.matchID);

  [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    if (error || objects.count == 0) {
      DLog(@"this is a new chat -- creating...");
      [weakSelf createChatObject];
    } else {
      DLog(@"found existing chat object... loading messages");
      id chatObj = [objects lastObject];
      [weakSelf setChatObject:chatObj];
      [weakSelf refresh];
    }
  }];
}

- (void)createChatObject {
  __weak id weakSelf = self;

  PFObject *object = [PFObject objectWithClassName:@"Chat"];

  [object setObject:_match.matchID forKey:@"parent"];
  [object setObject:_match.firstPlayer forKey:@"user1"];
  [object setObject:_match.secondPlayer forKey:@"user2"];

  [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (succeeded) {
      [weakSelf setChatObject:object];
      DLog(@"created chat object");
    } else {
      [[weakSelf delegate] didFailToLoadDataInChat:weakSelf error:error];
    }
  }];
}

- (NSString *)unreadKeyForCurrentUser {
  PFUser *user1 = [_chatObject objectForKey:@"user1"];

  NSString *unreadKey = (([[PFUser currentUser].objectId isEqualToString:user1.objectId])
                         ? @"lastRead1" : @"lastRead2");
  
  return unreadKey;
}

- (void)refresh {
  if (!_chatObject)
    return;

  __weak id weakSelf = self;

  PFQuery *query = [PFQuery queryWithClassName:@"ChatMessage"];

  [query includeKey:@"user"];
  [query whereKey:@"parent" equalTo:_chatObject];
  [query orderByAscending:@"createdAt"];

  query.limit = 50;

  [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    if (error) {
      [[weakSelf delegate] didFailToLoadDataInChat:weakSelf error:error];
      return;
    }

    NSArray *msgs = [objects map:^id(PFObject *obj) {
      ChatMessage *chatMsg = [ChatMessage new];

      chatMsg.who = [obj objectForKey:@"user"];
      chatMsg.what = [obj objectForKey:@"body"];
      chatMsg.when = obj.createdAt;

      return chatMsg;
    }];

    [weakSelf setMessages:msgs];

    ChatMessage *lastMsg = [msgs lastObject];

    NSDate *lastReadDate = [_chatObject objectForKey:[self unreadKeyForCurrentUser]];

    BOOL hasUnread = ((!lastReadDate && msgs.count > 0) ||
                      [lastMsg.when timeIntervalSinceDate:lastReadDate] > 10);

    [[weakSelf delegate] didLoadMessages:msgs
                                    chat:weakSelf
                               hasUnread:hasUnread];
  }];
}

- (void)markAllAsRead {
  if (!_chatObject) {
    DLog(@"no chat object! operation pending?");
    return;
  }

  DLog(@"marking as read");

  [_chatObject setObject:[NSDate date] forKey:[self unreadKeyForCurrentUser]];
  [_chatObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [error showParseError:@"mark chat as read"];
    }
  }];
}

- (void)postMessage:(NSString *)messageBody {
  if (!_chatObject) {
    DLog(@"no chat object! operation pending?");
    return;
  }

  __weak id weakSelf = self;

  ChatMessage *chatMessage = [ChatMessage new];

  chatMessage.who = [PFUser currentUser];
  chatMessage.when = [NSDate date];
  chatMessage.what = messageBody;

  PFObject *messageObject = [PFObject objectWithClassName:@"ChatMessage"];

  [messageObject setObject:[PFUser currentUser] forKey:@"user"];
  [messageObject setObject:messageBody forKey:@"body"];
  [messageObject setObject:_chatObject forKey:@"parent"];

  [_delegate willPostMessage:messageBody chat:self];

  [messageObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      [weakSelf didFailToLoadDataInChat:weakSelf error:error];
    } else {
      if (![weakSelf messages]) {
        [weakSelf setMessages:@[ chatMessage ]];
      } else {
        NSArray *messages = [[weakSelf messages] arrayByAddingObject:chatMessage];
        [weakSelf setMessages:messages];
      }
      [weakSelf markAllAsRead];
      [[weakSelf delegate] didPostMessage:messageBody chat:weakSelf];
    }
  }];
}

@end
