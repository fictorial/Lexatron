//
//  ChatViewController.m
//  Lexatron
//
//  Created by Brian Hammond on 8/25/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "ChatViewController.h"
#import "PushManager.h"

@interface ChatViewController ()
@property (nonatomic, strong) Chat *chat;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) NSDate *lastRefreshDate;
@property (nonatomic, weak) id<ChatViewControllerDelegate> delegate;
@end

@implementation ChatViewController

+ (id)controllerForMatch:(Match *)match
                delegate:(id<ChatViewControllerDelegate>)aDelegate {
  
  ChatViewController *vc = [[ChatViewController alloc] initWithNibName:nil bundle:nil];
  vc.chat = [Chat chatWithMatch:match delegate:vc];
  vc.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  vc.delegate = aDelegate;
  vc.lastRefreshDate = [NSDate date];
  return vc;
}

- (BOOL)shouldDisplayBackgroundBoardImage {
  return NO;
}

- (BOOL)requiresAuthenticatedUser {
  return YES;
}

- (BOOL)shouldShowSettingsButton {
  return NO;
}

- (void)loadView {
  [super loadView];

  self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];

  float w = self.view.bounds.size.width;
  float h = self.view.bounds.size.height;

  float cw = w * 3/4.;

  self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cw, h - SCALED(24))];
  _containerView.center = CGPointMake(w/2, h/2);
  _containerView.backgroundColor = [self bgColor];
  _containerView.layer.cornerRadius = 10;
  _containerView.clipsToBounds = YES;
  [self.view addSubview:_containerView];

  UIButton *button = [self makeButtonWithTitle:@"Send a Message" color:kGlossyGreenColor selector:@selector(doSendMessage:)];
  button.center = CGPointMake(cw/2, SCALED(10) + button.bounds.size.height/2);
  [_containerView addSubview:button];

  float margin = SCALED(10);
  float containerWidth = cw - SCALED(20);
  CGRect tableFrame = CGRectMake(cw/2 - containerWidth/2,
                                 margin + SCALED(10) + button.bounds.size.height,
                                 containerWidth,
                                 CGRectGetHeight(_containerView.bounds) - margin - (margin + SCALED(10) + button.bounds.size.height));

  self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
  _tableView.backgroundColor = [UIColor clearColor];
  _tableView.backgroundView = nil;
  _tableView.delegate = self;
  _tableView.dataSource = self;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.clipsToBounds = YES;
  [_containerView addSubview:_tableView];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(pushHandled:)
                                               name:kPushNotificationHandledNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appBecameActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
}

- (void)viewDidUnload {
  [super viewDidUnload];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [_containerView fadeIn:0.5 delegate:nil];

  if (_chat.messages.count > 0) {
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_chat.messages.count-1 inSection:0]
                      atScrollPosition:UITableViewScrollPositionBottom
                              animated:YES];
  }
  
  DLog(@"dt=%f",[_lastRefreshDate timeIntervalSinceNow]);

  if ([_lastRefreshDate timeIntervalSinceNow] < -10) {
    [self refresh];
  }

  [_chat markAllAsRead];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _chat.messages.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return [[self textForIndexPath:indexPath]
          sizeWithFont:_font
          constrainedToSize:CGSizeMake(_tableView.bounds.size.width*0.8, HUGE_VAL)
          lineBreakMode:UILineBreakModeWordWrap].height;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellIdentifier = @"chatTableCell";

  UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:cellIdentifier];

  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.font = _font;
    cell.textLabel.numberOfLines = 4;
    cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [UIColor whiteColor];
  }

  cell.textLabel.text = [self textForIndexPath:indexPath];

  ChatMessage *msg = [_chat.messages objectAtIndex:indexPath.row];
  if ([msg.who.objectId isEqualToString:_chat.match.firstPlayer.objectId]) {
    cell.textLabel.textColor = kTileColorPlayerOne;
  } else {
    cell.textLabel.textColor = kTileColorPlayerTwo;
  }

  return cell;
}

- (NSString *)textForIndexPath:(NSIndexPath *)indexPath {
  ChatMessage *msg = [_chat.messages objectAtIndex:indexPath.row];
  return [NSString stringWithFormat:@"<%@> %@", [msg.who usernameForDisplay], msg.what];
}

- (void)doSendMessage:(id)sender {
  YIPopupTextView *popupTextView = [[YIPopupTextView alloc] initWithPlaceHolder:@"" maxCount:150];
  popupTextView.delegate = self;
  popupTextView.showCloseButton = NO;
  [popupTextView showInView:self.view];
}

- (void)textViewDidChange:(UITextView *)textView {
  if ([textView.text hasSuffix:@"\n"]) {
    [(YIPopupTextView *)textView dismiss];
  }
}

- (void)popupTextView:(YIPopupTextView *)textView didDismissWithText:(NSString *)text {
  NSString *msg = [text trimWhitespace];

  if (msg.length == 0)
    return;

  msg = [msg substringToIndex:MIN(msg.length, 150)];

  [_chat postMessage:msg];
}

- (void)refresh {
  [self startTimeoutTimer];
  [_chat refresh];
  self.lastRefreshDate = [NSDate date];
}

- (void)didFailToLoadDataInChat:(Chat *)chat error:(NSError *)error {
  [self removeTimeoutTimer];

  [self showNoticeAlertWithCaption:[error localizedDescription]];

  __weak id weakSelf = self;
  [self performBlock:^(id sender) {
    [weakSelf hideAllAlerts];
    [weakSelf goBack];
  } afterDelay:1.5];
}

- (void)didLoadMessages:(NSArray *)messages
                   chat:(Chat *)chat
              hasUnread:(BOOL)currentUserHasUnreadMessages {

  DLog(@"did load messages: %d", messages.count);

  [self removeTimeoutTimer];

  [_tableView reloadData];

  if (messages.count > 0) {
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:messages.count-1 inSection:0]
                      atScrollPosition:UITableViewScrollPositionMiddle
                              animated:YES];
  }
  
  [_delegate didLoadMessagesInChat:_chat
                         hasUnread:currentUserHasUnreadMessages];
}

- (void)willPostMessage:(NSString *)message chat:(Chat *)chat {
  [self startTimeoutTimer];
  [self showActivityHUD];
}

- (void)didPostMessage:(NSString *)message chat:(Chat *)chat {
  [self removeTimeoutTimer];
  [self hideActivityHUD];

  [_tableView reloadData];

  if (_chat.messages.count > 0) {
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_chat.messages.count-1 inSection:0]
                      atScrollPosition:UITableViewScrollPositionMiddle
                              animated:YES];
  }
}

#pragma mark - utility

- (UIColor *)accentColor {
  return [UIColor colorWithRed:0.839 green:0.733 blue:0.376 alpha:1.000];
}

- (UIColor *)bgColor {
  return [UIColor colorWithWhite:0 alpha:0.75];
}

#pragma mark - notifications

- (void)pushHandled:(NSNotification *)notification {
  // We received a push notification about a match so just reload whatever we're looking at
  // to be sure we have the latest info.

  if (self.navigationController.topViewController == self)
    [self refresh];
}

- (void)appBecameActive:(NSNotification *)notification {
  [self refresh];
}

@end
