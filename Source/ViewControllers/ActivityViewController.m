//
//  ActivityViewController.m
//  Lexatron
//
//  Created by Brian Hammond on 8/14/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "ActivityViewController.h"
#import "PushManager.h"
#import "Match.h"
#import "Turn.h"
#import "MatchViewController.h"
#import "FindOpponentViewController.h"
#import "LQAudioManager.h"
#import "WelcomeViewController.h"
#import "UIView-GeomHelpers.h"

#import "SSPullToRefreshSimpleContentView.h"

typedef enum {
  kActivityModeYourTurn,
  kActivityModeTheirTurn,
  kActivityModeCompleted
} ActivityMode;

@interface ActivityViewController ()

@property (nonatomic, copy) NSArray *synopses;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *yourTurnButton;
@property (nonatomic, strong) UIButton *theirTurnButton;
@property (nonatomic, strong) UIButton *completedButton;
@property (nonatomic, strong) UILabel *noMatchesLabel;
@property (nonatomic, strong) SSPullToRefreshView *pullToRefreshView;
@property (nonatomic, assign) ActivityMode mode;
@property (nonatomic, retain) NSDate *lastRefreshDate;

@end

@implementation ActivityViewController

- (BOOL)requiresAuthenticatedUser {
  return YES;
}

- (UIButton *)makeChooserButtonWithTitle:(NSString *)title selector:(SEL)selector {
  float containerWidth = self.view.bounds.size.width * 3/4.;
  float margin = SCALED(12);
  int buttonCount = 3;
  float totalMargin = (buttonCount + 1) * margin;
  float buttonWidth = containerWidth / buttonCount - totalMargin;

  UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
  button.bounds = CGRectMake(0, 0, buttonWidth, kGlossyButtonHeight);
  button.backgroundColor = [self bgColor];
  button.layer.cornerRadius = 5;
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  [button setTitleColor:[self accentColor] forState:UIControlStateNormal];
  [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
  [button addTarget:self action:@selector(playButtonSound:) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (void)loadView {
  [super loadView];

  float w = self.view.bounds.size.width;
  float h = [self effectiveViewHeight];

  float cw = w * 3/4.;

  self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cw, h - SCALED(24))];
  _containerView.center = CGPointMake(w/2, h/2);
  _containerView.backgroundColor = [self bgColor];
  _containerView.layer.cornerRadius = 10;
  _containerView.clipsToBounds = YES;
  [self.view addSubview:_containerView];

  self.yourTurnButton = [self makeChooserButtonWithTitle:NSLocalizedString(@"Your turn", nil) selector:@selector(updateMatchesFromSender:)];
  self.theirTurnButton = [self makeChooserButtonWithTitle:NSLocalizedString(@"Their turn", nil) selector:@selector(updateMatchesFromSender:)];
  self.completedButton = [self makeChooserButtonWithTitle:NSLocalizedString(@"Completed", nil) selector:@selector(updateMatchesFromSender:)];

  float margin = SCALED(10);

  _theirTurnButton.center = CGPointMake(cw/2., SCALED(35));
  _yourTurnButton.center = CGPointMake(CGRectGetMidX(_theirTurnButton.frame) - CGRectGetWidth(_theirTurnButton.bounds) - margin, SCALED(35));
  _completedButton.center = CGPointMake(CGRectGetMidX(_theirTurnButton.frame) + CGRectGetWidth(_theirTurnButton.bounds) + margin, SCALED(35));

  [_containerView addSubview:_yourTurnButton];
  [_containerView addSubview:_theirTurnButton];
  [_containerView addSubview:_completedButton];

  float containerWidth = cw - SCALED(20);
  CGRect tableFrame = CGRectMake(cw/2 - containerWidth/2,
                                 CGRectGetMaxY(_yourTurnButton.frame) + margin,
                                 containerWidth,
                                 CGRectGetHeight(_containerView.bounds) - margin - CGRectGetMaxY(_yourTurnButton.frame) - margin);

  self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
  _tableView.backgroundColor = [UIColor clearColor];
  _tableView.backgroundView = nil;
  _tableView.delegate = self;
  _tableView.dataSource = self;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.clipsToBounds = YES;
  [_containerView addSubview:_tableView];

  self.noMatchesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(_tableView.bounds), kFontSizeRegular*5)];
  _noMatchesLabel.center = CGPointMake(CGRectGetWidth(_tableView.bounds)/2, CGRectGetHeight(_tableView.bounds)/2 - SCALED(50));
  _noMatchesLabel.hidden = YES;
  _noMatchesLabel.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  _noMatchesLabel.backgroundColor = [UIColor clearColor];
  _noMatchesLabel.text = NSLocalizedString(@"No matches found.\n\nTap the + button to challenge a friend!", nil);
  _noMatchesLabel.textColor = [UIColor whiteColor];
  _noMatchesLabel.textAlignment = UITextAlignmentCenter;
  _noMatchesLabel.numberOfLines = 5;
  _noMatchesLabel.lineBreakMode = UILineBreakModeWordWrap;
  _noMatchesLabel.shadowColor = [UIColor darkTextColor];
  _noMatchesLabel.shadowOffset = CGSizeMake(0, -1);
  [_tableView addSubview:_noMatchesLabel];

  UIButton *newMatchButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [newMatchButton setImage:[UIImage imageWithName:@"NewMatchButton"] forState:UIControlStateNormal];
  [newMatchButton sizeToFit];
  newMatchButton.center = CGPointMake(self.view.bounds.size.width - newMatchButton.bounds.size.width/2-3, newMatchButton.bounds.size.height/2+3);
  [newMatchButton addTarget:self action:@selector(showFindOpponent:) forControlEvents:UIControlEventTouchUpInside];
  [newMatchButton addStandardShadowing];
  [self.view addSubview:newMatchButton];

  self.pullToRefreshView = [[SSPullToRefreshView alloc] initWithScrollView:_tableView delegate:self];
  SSPullToRefreshSimpleContentView *contentView = [[SSPullToRefreshSimpleContentView alloc] initWithFrame:CGRectZero];
  contentView.statusLabel.textColor = [self accentColor];
  contentView.statusLabel.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  contentView.activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
  self.pullToRefreshView.contentView = contentView;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(pushHandled:)
                                               name:kPushNotificationHandledNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appBecameActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(turnDidHappen:)
                                               name:kTurnDidEndNotification
                                             object:nil];

  self.mode = kActivityModeYourTurn;
}

- (void)turnDidHappen:(NSNotification *)notification {
  Match *match = [notification.userInfo objectForKey:@"match"];

  if (match.passAndPlay)
    return;

  if (match.state == kMatchStateEndedDeclined && _mode == kActivityModeYourTurn)
    [self refresh];
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

  [self hideActivityHUD];

  [_containerView fadeIn:0.5 delegate:nil];

  [self performBlock:^(id sender) {
    [self refresh];
  } afterDelay:1];
}

- (BOOL)shouldShowBackButton {
  return (![[self.navigationController.viewControllers objectAtIndex:0] isKindOfClass:WelcomeViewController.class] &&
          [self.navigationController.viewControllers lastObject] == self);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _synopses.count;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellIdentifier = @"activityTableCell";

  UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:cellIdentifier];

  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

    cell.textLabel.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
    cell.detailTextLabel.font = [UIFont fontWithName:kFontName size:kFontSizeSmall];

    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];

    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];

    cell.textLabel.numberOfLines = 4;
    cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;

    cell.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    cell.accessoryType = UITableViewCellAccessoryNone;

    UIImageView *disclosureIV = [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"DisclosureButton"]];
    [disclosureIV sizeToFit];
    cell.accessoryView = disclosureIV;
  }

  NSDictionary *synopsis = [_synopses objectAtIndex:indexPath.row];
  NSString *desc = [synopsis objectForKey:@"desc"];
  NSString *updatedAtInWords = [synopsis objectForKey:@"updated"];

  cell.textLabel.text = desc;
  cell.detailTextLabel.text = updatedAtInWords;
  cell.detailTextLabel.textAlignment = UITextAlignmentRight;

  return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return SCALED(60);
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [aTableView deselectRowAtIndexPath:indexPath animated:YES];

  [self showActivityHUD];

  NSString *matchID = [[_synopses objectAtIndex:indexPath.row] objectForKey:@"matchID"];

  PFQuery *query = [PFQuery queryWithClassName:@"Match"];

  __weak id weakSelf = self;

  [query getObjectInBackgroundWithId:matchID block:^(PFObject *object, NSError *error) {
    [weakSelf hideActivityHUD];

    if (error)
      return;

    [Match matchWithExistingMatchObject:object block:^(Match *aMatch, NSError *error) {
      if (error)
        return;

      MatchViewController *vc = [MatchViewController controllerWithMatch:aMatch];
      [[weakSelf navigationController] pushViewController:vc animated:NO];
    }];
  }];
}

#pragma mark - util

- (UIColor *)accentColor {
  return [UIColor colorWithRed:0.839 green:0.733 blue:0.376 alpha:1.000];
}

- (UIColor *)bgColor {
  return [UIColor colorWithWhite:0 alpha:0.75];
}

#pragma mark - actions

- (void)showFindOpponent:(id)sender {
  [[LQAudioManager sharedManager] playEffect:kEffectSelect];
  FindOpponentViewController *vc = [FindOpponentViewController controller];
  [self.navigationController pushViewController:vc animated:NO];
}

- (void)updateMatchesFromSender:(id)sender {
  if (sender == _yourTurnButton) {
    self.mode = kActivityModeYourTurn;
  } else if (sender == _theirTurnButton) {
    self.mode = kActivityModeTheirTurn;
  } else {
    self.mode = kActivityModeCompleted;
  }

  self.lastRefreshDate = nil;

  [self refresh];
}

- (void)updateChooserButtonState {
  switch (self.mode) {
    case kActivityModeYourTurn:
      _yourTurnButton.alpha = 1.0;
      _theirTurnButton.alpha = 0.7;
      _completedButton.alpha = 0.7;

      _yourTurnButton.backgroundColor = [self accentColor];
      _theirTurnButton.backgroundColor = [self bgColor];
      _completedButton.backgroundColor = [self bgColor];

      [_yourTurnButton setTitleColor:[self bgColor] forState:UIControlStateNormal];
      [_theirTurnButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      [_completedButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      break;

    case kActivityModeTheirTurn:
      _yourTurnButton.alpha = 0.7;
      _theirTurnButton.alpha = 1.0;
      _completedButton.alpha = 0.7;

      _yourTurnButton.backgroundColor = [self bgColor];
      _theirTurnButton.backgroundColor = [self accentColor];
      _completedButton.backgroundColor = [self bgColor];

      [_yourTurnButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      [_theirTurnButton setTitleColor:[self bgColor] forState:UIControlStateNormal];
      [_completedButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      break;

    case kActivityModeCompleted:
      _yourTurnButton.alpha = 0.7;
      _theirTurnButton.alpha = 0.7;
      _completedButton.alpha = 1.0;

      _yourTurnButton.backgroundColor = [self bgColor];
      _theirTurnButton.backgroundColor = [self bgColor];
      _completedButton.backgroundColor = [self accentColor];

      [_yourTurnButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      [_theirTurnButton setTitleColor:[self accentColor] forState:UIControlStateNormal];
      [_completedButton setTitleColor:[self bgColor] forState:UIControlStateNormal];
      break;
  }
}

#pragma mark - Pull to refresh

- (BOOL)pullToRefreshViewShouldStartLoading:(SSPullToRefreshView *)view {
  // Can refresh if data are too stale or if you are looking at the matches in which you can act.
  // The idea with the latter is that you'll play a turn and return to the activity viewer.
  // If we do NOT reload you'll see the match you just played even though it's not your turn now.

  return !_lastRefreshDate || abs([[NSDate date] timeIntervalSinceDate:_lastRefreshDate]) > 15 || _mode == kActivityModeYourTurn;
}

- (void)pullToRefreshViewDidStartLoading:(SSPullToRefreshView *)view {
  _noMatchesLabel.hidden = YES;

  SEL selector;

  switch (_mode) {
    case kActivityModeYourTurn:
      selector = @selector(actionableMatches:);
      break;

    case kActivityModeTheirTurn:
      selector = @selector(unactionableMatches:);
      break;

    case kActivityModeCompleted:
      selector = @selector(completedMatches:);
      break;
  }

  __weak id weakSelf = self;

  _yourTurnButton.enabled = _theirTurnButton.enabled = _completedButton.enabled = NO;

  [self startTimeoutTimer];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [[PFUser currentUser] performSelector:selector withObject:^(NSArray *objects, NSError *error) {
#pragma clang diagnostic pop

    [weakSelf removeTimeoutTimer];

    [[weakSelf pullToRefreshView] finishLoading];

    if (error) {
      [error showParseError:NSLocalizedString(@"fetch matches", nil)];
      return;
    }

    [weakSelf setSynopses:objects];

    if ([[weakSelf synopses] count] == 0) {
      [[weakSelf noMatchesLabel] fadeIn:0.4 delegate:nil];
    } else {
      [weakSelf noMatchesLabel].hidden = YES;
    }

    if ([weakSelf mode] == kActivityModeCompleted) {
      [weakSelf showRecordLabel:YES];
    } else {
      [weakSelf showRecordLabel:NO];
    }

    [[weakSelf tableView] reloadData];
    [[weakSelf tableView] setHidden:NO];

    [[weakSelf yourTurnButton] setEnabled:YES];
    [[weakSelf theirTurnButton] setEnabled:YES];
    [[weakSelf completedButton] setEnabled:YES];
  }];
}

- (void)pullToRefreshViewDidFinishLoading:(SSPullToRefreshView *)view {
  self.lastRefreshDate = [NSDate date];
}

- (void)refresh {
  [self removeTimeoutTimer];

  [self updateChooserButtonState];

  [_pullToRefreshView finishLoading];

  [self performBlock:^(id sender) {
    [_pullToRefreshView startLoadingAndExpand:YES];
  } afterDelay:0.4];

}

enum {
  kRecordLabelTag = 9898
};

- (void)showRecordLabel:(BOOL)show {
  UILabel *label = (UILabel *)[self.view viewWithTag:kRecordLabelTag];

  if (label) {
    if (!label.hidden)
      _tableView.top = _tableView.top - label.height;
    
    [label removeFromSuperview];
  }

  if (!show)
    return;

  label = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMinX(_tableView.frame),
                                                    CGRectGetMinY(_tableView.frame),
                                                    CGRectGetWidth(_tableView.frame),
                                                    kFontSizeSmall+SCALED(5))];
  label.font = [UIFont fontWithName:kFontName size:kFontSizeSmall];
  label.tag = kRecordLabelTag;
  label.backgroundColor = [self accentColor];
  label.textColor = [self bgColor];
  label.textAlignment = UITextAlignmentCenter;
  label.hidden = YES;
  label.layer.cornerRadius = SCALED(4);
  [_containerView addSubview:label];

  __weak id weakSelf = self;

  [[PFUser currentUser] getRecord:^(NSDictionary *dict, NSError *error) {
    if (error) {
      [error showParseError:@"fetch win-loss-tie record"];
      return;
    }

    [weakSelf updateAndShowRecordLabelWon:[dict intForKey:@"w"]
                                     lost:[dict intForKey:@"l"]
                                     tied:[dict intForKey:@"t"]];
  }];
}

- (void)updateAndShowRecordLabelWon:(int)won lost:(int)lost tied:(int)tied {
  DLog(@"done fetching your record: %d-%d-%d", won, lost, tied);

  UILabel *label = (UILabel *)[self.view viewWithTag:kRecordLabelTag];

  if (!label)
    return;

  if (won == 0 && lost == 0 && tied == 0) {
    if (!label.hidden)
      _tableView.top = _tableView.top - label.height;

    label.hidden = YES;
    return;
  }

  label.text = [NSString stringWithFormat:@"Your Record: %d Win%@, %d Loss%@, %d Tie%@",
                won, won == 1 ? @"" : @"s",
                lost, lost == 1 ? @"" : @"es",
                tied, tied == 1 ? @"" : @"s"];
  
  if (label.hidden) {
    label.hidden = NO;
    _tableView.top = _tableView.top + label.height;
  }
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
