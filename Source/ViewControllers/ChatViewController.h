//
//  ChatViewController.h
//  Lexatron
//
//  Created by Brian Hammond on 8/25/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "BaseViewController.h"
#import "YIPopupTextView.h"
#import "Chat.h"

@class Match;

@protocol ChatViewControllerDelegate <NSObject>

- (void)didLoadMessagesInChat:(Chat *)chat
                    hasUnread:(BOOL)hasUnread;

@end

@interface ChatViewController : BaseViewController <UITableViewDataSource, UITableViewDelegate, YIPopupTextViewDelegate, ChatDelegate>

+ (id)controllerForMatch:(Match *)match
                delegate:(id<ChatViewControllerDelegate>)delegate;

- (void)refresh;

@end
