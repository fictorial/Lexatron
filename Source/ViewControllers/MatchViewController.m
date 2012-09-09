//
//  MatchViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "MatchViewController.h"
#import "BoardScrollView.h"
#import "BoardView.h"
#import "RackView.h"
#import "TileView.h"
#import "TileChooserView.h"
#import "LQAudioManager.h"
#import "ExplosionView.h"
#import "Chat.h"
#import "ChatViewController.h"

enum {
  kViewStateNormal,        // viewing/playing active match
  kViewStateSwap,          // swapping/exchanging ≥1 rack letters
  kViewStateEnded,         // viewing a match that has ended
  kViewStateBlankChooser   // choosing a substitute letter for a placed blank tile
};

enum {
  kMatchEndSummaryLabelTag = 888,
  kMatchEndRematchButtonTag,
  kDropTargetViewTag
};

@interface MatchViewController ()
@property (nonatomic, retain, readwrite) Match *match;
@property (nonatomic, strong) BoardScrollView *boardScrollView;
@property (nonatomic, strong) RackView *rackView;
@property (nonatomic, strong) UILabel *player1Label;
@property (nonatomic, strong) UILabel *player2Label;
@property (nonatomic, strong) UIImageView *player1ColorTile;
@property (nonatomic, strong) UIImageView *player2ColorTile;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIButton *chatButton;
@property (nonatomic, strong) UIButton *swapButton;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UILabel *endedLabel;
@property (nonatomic, strong) UIView *swapInfoView;
@property (nonatomic, assign) int viewState;
@property (nonatomic, assign) BOOL seenMostRecentTurnDescription;
@property (nonatomic, strong) ChatViewController *chatVC;
@end

@implementation MatchViewController

+ (id)controllerWithMatch:(Match *)aMatch {
  MatchViewController *vc = [self controller];

  vc.match = aMatch;
  aMatch.delegate = vc;

  if (!aMatch.passAndPlay && aMatch.matchID)
    vc.chatVC = [ChatViewController controllerForMatch:aMatch delegate:vc];
  
  return vc;
}

- (void)loadView {
  [super loadView];

  [self setupView];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appBecameActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
}

- (void)setupView {
  [self setupBoard];
  [self setupScoreboard];
  [self setupHUD];   // before rack since rack positions based on hud buttons
  [self setupRack];
  [self setupSwapInfoView];
}

- (void)setupBoard {
  float w = self.view.bounds.size.width;
  float h = self.view.bounds.size.height;

  self.boardScrollView = [[BoardScrollView alloc] initWithFrame:CGRectMake(0, 0, kBoardWidthPoints, kBoardHeightPoints)];
  _boardScrollView.backgroundColor = [UIColor clearColor];
  _boardScrollView.center = CGPointMake(w/2, h/2);
  _boardScrollView.delegate = self;
  [self.view addSubview:_boardScrollView];
  [self updateBoardFromMatchState];
}

- (void)updateBoardFromMatchState {
  [_match.board enumerateKeysAndObjectsUsingBlock:^(NSNumber *cellNumber, Letter *letter, BOOL *stop) {
    CGRect cellRect = [_boardScrollView.boardView boardFromCellX:cellX(letter.cellIndex) y:cellY(letter.cellIndex)];
    TileView *boardTileView = [TileView viewWithFrame:cellRect letter:letter];
    [boardTileView configureForBoardDisplay];
    [_boardScrollView.boardView addSubview:boardTileView];
  }];
}

- (UILabel *)makeScoreboardLabel {
  UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
  label.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  label.textColor = [[UIColor darkTextColor] colorWithAlphaComponent:0.7];
  label.backgroundColor = [UIColor clearColor];
  label.numberOfLines = 2;
  label.textAlignment = UITextAlignmentCenter;
  label.shadowColor = [UIColor colorWithWhite:1 alpha:0.4];
  label.shadowOffset = CGSizeMake(0,1);
  return label;
}

- (void)setupScoreboard {
  self.player1Label = [self makeScoreboardLabel];
  self.player2Label = [self makeScoreboardLabel];
  [self.view addSubview:_player1Label];
  [self.view addSubview:_player2Label];

  self.player1ColorTile = [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"Player1Tile"]];
  self.player2ColorTile = [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"Player2Tile"]];
  [self.view addSubview:_player1ColorTile];
  [self.view addSubview:_player2ColorTile];

  [self updateScoreboard];  // sets .text
  [self updateScoreboardTiles];
}

- (void)updateScoreboard {
  _player1Label.text = [NSString stringWithFormat:@"%@   %d",
                        [[_match playerForPlayerNumber:0] usernameForDisplay],
                        _match.scoreForFirstPlayer];

  _player2Label.text = [NSString stringWithFormat:@"%@   %d",
                        [[_match playerForPlayerNumber:1] usernameForDisplay],
                        _match.scoreForSecondPlayer];

  _player1Label.alpha = _match.currentPlayerNumber == 0 ? 1 : 0.4;
  _player2Label.alpha = _match.currentPlayerNumber == 1 ? 1 : 0.4;

  float player1Width = [_player1Label.text sizeWithFont:_player1Label.font].width;
  float player2Width = [_player2Label.text sizeWithFont:_player2Label.font].width;

  float margin = SCALED(10);
  float bigMargin = SCALED(25);


  float fullWidth = (_player1ColorTile.image.size.width + margin +
                     player1Width + bigMargin + player2Width +
                     margin + _player2ColorTile.image.size.width);

  float labelHeight = SCALED(20);
  float labelY = SCALED(30) - labelHeight/2;

  _player1Label.frame = CGRectMake(0,0,player1Width,labelHeight);
  _player2Label.frame = CGRectMake(0,0,player2Width,labelHeight);

  float cx = CGRectGetWidth(self.view.bounds)/2;

  _player1ColorTile.center = CGPointMake(cx - fullWidth/2 + _player1ColorTile.image.size.width/2, labelY);
  _player1Label.center = CGPointMake(CGRectGetMaxX(_player1ColorTile.frame) + margin + player1Width/2, labelY);

  _player2ColorTile.center = CGPointMake(CGRectGetMaxX(_player1Label.frame) + bigMargin + _player2ColorTile.image.size.width/2, labelY);
  _player2Label.center = CGPointMake(CGRectGetMaxX(_player2ColorTile.frame) + margin + player2Width/2, labelY);
}

- (void)updateScoreboardTiles {
  UIImageView *activeIV, *inactiveIV;

  if (_match.currentPlayerNumber == 0) {
    activeIV = _player1ColorTile;
    inactiveIV = _player2ColorTile;
  } else {
    activeIV = _player2ColorTile;
    inactiveIV = _player1ColorTile;
  }

  [inactiveIV.layer removeAllAnimations];
  [activeIV.layer addAnimation:[self pulseAnimation] forKey:@"transform.scale"];
}

- (CABasicAnimation *)pulseAnimation {
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];

  animation.duration = 0.4;
  animation.fromValue = @(1);
  animation.toValue = @(0.65);
  animation.repeatCount = HUGE_VALF;
  animation.autoreverses = YES;

  return animation;
}

- (void)setupRack {
  CGFloat rackWidth = SCALED(40)*kRackTileCount + (kRackTileCount-1) * SCALED(1);
  CGFloat rackHeight = SCALED(40);

  [_rackView removeFromSuperview];

  self.rackView = [[RackView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width/2 - rackWidth/2,
                                                             CGRectGetMidY(_swapButton.frame) - rackHeight/2,
                                                             rackWidth, rackHeight)
                                          letters:[_match rackForCurrentUser]
                                     dragDelegate:self];
  [self.view addSubview:_rackView];
}

- (void)setupHUD {
  [self addSwapButton];
  [self addSubmitButton];
  [self addShuffleButton];

  if (!_match.passAndPlay && _match.matchID)
    [self addChatButton];
}

- (void)addSwapButton {
  UIImage *swapButtonImage = [UIImage imageWithName:@"SwapButton"];
  self.swapButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_swapButton setImage:swapButtonImage forState:UIControlStateNormal];
  [_swapButton sizeToFit];
  _swapButton.center = CGPointMake(swapButtonImage.size.width*1.5+kButtonMargin*2,
                                   CGRectGetHeight(self.view.frame) - swapButtonImage.size.height/2 - kButtonMargin);
  [_swapButton addTarget:self action:@selector(doShowSwapView:) forControlEvents:UIControlEventTouchUpInside];
  [_swapButton addStandardShadowing];
  [self.view addSubview:_swapButton];
}

- (void)addSubmitButton {
  UIImage *submitButtonImage = [UIImage imageWithName:@"SubmitButton"];
  self.submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_submitButton setImage:submitButtonImage forState:UIControlStateNormal];
  [_submitButton sizeToFit];
  _submitButton.center = CGPointMake(self.view.bounds.size.width-submitButtonImage.size.width/2-kButtonMargin,
                                     self.view.bounds.size.height-submitButtonImage.size.height/2-kButtonMargin);
  [_submitButton addTarget:self action:@selector(doSubmitTurn:) forControlEvents:UIControlEventTouchUpInside];
  [_submitButton addStandardShadowing];
  [self.view addSubview:_submitButton];
}

- (void)doSubmitTurn:(id)sender {
  if (!_match.passAndPlay && ![_match currentUserIsCurrentPlayer]) {
    [self showNotYourTurnError];
    return;
  }

  if ([_match lettersOnBoardPlacedInCurrentTurn].count == 0) {
    __weak id weakSelf = self;
    [self showConfirmAlertWithCaption:@"You have not placed any letters on the board. Are you sure you want to pass your turn?" block:^(int buttonPressed) {
      if (buttonPressed == 1) {  // Yes
        [weakSelf passTurn];
      }
    }];
    return;
  }

  NSError *error = [_match play];

  if (error) {
    DLog(@"failed: %@", [error localizedDescription]);

    [self performBlock:^(id sender) {
      [self showNoticeAlertWithCaption:[error localizedDescription]];
    } afterDelay:0.33];
  }

  // NB: zoomOut happens in match:turnDidHappen: and not here.

  [TestFlight passCheckpoint:@"matchPlayedTurn"];
}

- (void)addShuffleButton {
  UIImage *shuffleButtonImage = [UIImage imageWithName:@"ShuffleButton"];
  self.shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_shuffleButton setImage:shuffleButtonImage forState:UIControlStateNormal];
  [_shuffleButton sizeToFit];
  _shuffleButton.center = CGPointMake(self.view.bounds.size.width-shuffleButtonImage.size.width*1.5-kButtonMargin*2,
                                      self.view.bounds.size.height-shuffleButtonImage.size.height/2-kButtonMargin);
  [_shuffleButton addTarget:self action:@selector(doShuffle:) forControlEvents:UIControlEventTouchUpInside];
  [_shuffleButton addStandardShadowing];
  [self.view addSubview:_shuffleButton];
}

- (void)doShuffle:(id)sender {
  [self recall];
  [_match shuffleRack];
  [self setupRack];
  [[LQAudioManager sharedManager] playEffect:kEffectShuffle];
  [TestFlight passCheckpoint:@"matchShuffledRack"];
}

- (void)addChatButton {
  UIImage *chatButtonImage = [UIImage imageWithName:@"ChatButton"];
  self.chatButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_chatButton setBackgroundImage:chatButtonImage forState:UIControlStateNormal];
  [_chatButton sizeToFit];
  _chatButton.titleLabel.font = [UIFont fontWithName:kFontName size:kFontSizeSmall];
  [_chatButton setTitleColor:[UIColor colorWithWhite:0 alpha:0.5] forState:UIControlStateNormal];
  _chatButton.center = CGPointMake(self.view.bounds.size.width-chatButtonImage.size.width/2-SCALED(5),
                                   chatButtonImage.size.height/2+SCALED(5));
  [_chatButton addTarget:self action:@selector(doChat:) forControlEvents:UIControlEventTouchUpInside];
  [_chatButton addStandardShadowing];
  [self.view addSubview:_chatButton];
}

- (void)doChat:(id)sender {
  [[LQAudioManager sharedManager] playEffect:kEffectSelect];
  [self.navigationController pushViewController:_chatVC animated:NO];
}

- (void)didLoadMessagesInChat:(Chat *)chat hasUnread:(BOOL)hasUnread {
  [_chatButton.layer removeAllAnimations];

  if (hasUnread)
    [_chatButton.layer addAnimation:[self pulseAnimation] forKey:@"transform.scale"];
}

- (void)passTurn {
  if (!_match.passAndPlay && ![_match currentUserIsCurrentPlayer]) {
    [self showNotYourTurnError];
    return;
  }

  [self setViewState:kViewStateNormal];

  [self recall];
  [_match pass];
  [TestFlight passCheckpoint:@"matchPassedTurn"];
}

- (void)resign {
  // See ticket 109 for details but basically we don't want to allow both players to be
  // able to write to the same match object on the backend simultaneously since we have
  // to do all updates on the client and thus could overwrite each other's changes.
  // Thus, players have to wait until it's their turn to resign.

  if (!_match.passAndPlay && ![_match currentUserIsCurrentPlayer]) {
    [self showNotYourTurnError];
    return;
  }

  _match.delegate = nil;
  [_match resign];

  [TestFlight passCheckpoint:@"matchResigned"];

  [self setViewState:kViewStateNormal];

  [self goBack];

  // first goBack closes action view
  if (_match.passAndPlay)
    [self goBack];
}

- (void)setupSwapInfoView {
  int bw = kGlossyButtonWidth;  // TODO
  int bh = kGlossyButtonHeight;
  int margin = SCALED(15);
  int buttonCount = 2;
  int hw = self.view.bounds.size.width/2;
  int hh = self.view.bounds.size.height/2;
  int labelHeight = SCALED(30);
  int vh = bh * buttonCount + margin * (buttonCount-1) + labelHeight;
  int vw = bw;
  int vx = hw - vw/2;
  int vy = hh - vh/2;

  self.swapInfoView = [[UIView alloc] initWithFrame:CGRectMake(vx, vy, vw, vh)];
  _swapInfoView.backgroundColor = [UIColor clearColor];

  UILabel *directions = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vw, labelHeight)];
  directions.backgroundColor = [UIColor clearColor];
  directions.textColor = [UIColor whiteColor];
  directions.font = [UIFont fontWithName:kFontName size:kFontSizeRegular];
  directions.shadowColor = [UIColor blackColor];
  directions.shadowOffset = CGSizeMake(0,1);
  directions.textAlignment = UITextAlignmentCenter;
  [_swapInfoView addSubview:directions];

  UIButton *swapButton = [self makeButtonWithTitle:NSLocalizedString(@"Swap Selected", nil)
                                             color:kGlossyOrangeColor
                                          selector:@selector(doSwapSelected:)];

  UIButton *cancelButton = [self makeButtonWithTitle:NSLocalizedString(@"Cancel", nil)
                                               color:kGlossyBlackColor
                                            selector:@selector(doCancelSwap:)];

  swapButton.center = CGPointMake(vw/2, CGRectGetMaxY(directions.frame));
  cancelButton.center = CGPointMake(vw/2, swapButton.center.y + bh + margin);

  [_swapInfoView addSubview:swapButton];
  [_swapInfoView addSubview:cancelButton];

  [self.view addSubview:self.swapInfoView];

  _swapInfoView.hidden = YES;
}

- (void)doShowSwapView:(id)sender {
  if (![_match canExchangeLettersInRack]) {
    [self showNoticeAlertWithCaption:@"There are not enough letters remaining to swap"];
    return;
  }

  self.viewState = kViewStateSwap;
}

- (void)enterSwapState {
  [self recall];

  _rackView.hidden = NO;
  _endedLabel.hidden = YES;
  _submitButton.hidden = YES;
  _chatButton.hidden = YES;
  _shuffleButton.hidden = YES;
  _swapButton.hidden = YES;
  _swapInfoView.hidden = YES; // until slide in below

  self.boardScrollView.userInteractionEnabled = NO;
  _rackView.userInteractionEnabled = NO;

  [_swapInfoView backInFrom:kFTAnimationBottom withFade:YES duration:0.4 delegate:nil];
  [[LQAudioManager sharedManager] playEffect:kEffectSlide];

  [self performBlock:^(id sender) {
    [_rackView beginSelectionMode];
    _rackView.userInteractionEnabled = YES;
  } afterDelay:0.25];
}

- (void)leaveSwapState {
  [_swapInfoView backOutTo:kFTAnimationBottom withFade:YES duration:0.4 delegate:nil];
  [_rackView endSelectionMode];
}

- (void)doCancelSwap:(id)sender {
  self.viewState = kViewStateNormal;
}

- (void)doSwapSelected:(id)sender {
  NSSet *selectedIndexes = [_rackView endSelectionMode];

  if (selectedIndexes.count > 0) {
    [_match exchangeRackLettersAtIndexes:[selectedIndexes allObjects]];
    [[LQAudioManager sharedManager] playEffect:kEffectShuffle];
    [TestFlight passCheckpoint:@"matchSwappedLetters"];
  }

  self.viewState = kViewStateNormal;
}

- (void)viewWillDisappear:(BOOL)animated {
  _boardScrollView.delegate = nil;
  [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  _boardScrollView.delegate = self;

  DLog(@"showing match: %d", _match.state);

  _boardScrollView.alpha = 0;
  [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
    _boardScrollView.alpha = 1;
  } completion:^(BOOL finished) {
  }];

  __weak id weakSelf = self;

  if (_match.state == kMatchStatePending &&
      !_match.passAndPlay &&
      [_match currentUserPlayerNumber] != 0 &&
      !_hasAcceptedChallenge) {

    NSString *format = NSLocalizedString(@"%@ challenged you to a match!",
                                         @"%@ is the username of the requesting player");

    NSString *text = [NSString stringWithFormat:format, [_match.firstPlayer usernameForDisplay]];

    [self showAlertWithCaption:text
                        titles:@[ @"Reject", @"Accept" ]
                        colors:@[ kGlossyBlackColor, kGlossyGreenColor ]
                         block:^(int buttonPressed) {
                           if (buttonPressed == 0) {  // reject
                             [_match decline];
                             [weakSelf showActivityHUD];
                             [TestFlight passCheckpoint:@"matchDeclinedChallenge"];
                             // See -match:turnDidHappen: for when we go back and why not here.
                           } else {
                             [weakSelf setViewState:kViewStateNormal];

                             [weakSelf performBlock:^(id sender) {
                               [weakSelf zoomToLettersOwnedByCurrentPlayer];
                             } afterDelay:2];

                             [TestFlight passCheckpoint:@"matchAcceptedChallenge"];
                           }
                         }];
  } else if (_match.state == kMatchStateEndedNormal ||
             _match.state == kMatchStateEndedResign) {

    self.viewState = kViewStateEnded;
    [self handleMatchEnded];

  } else {
    self.viewState = kViewStateNormal;

    if ([_match currentUserIsCurrentPlayer]) {
      [self.boardScrollView zoomOut];
//      [self performBlock:^(id sender) {
//        [weakSelf zoomToLettersOwnedByCurrentPlayer];
//      } afterDelay:2];
    }

    [self updateScoreboardTiles];
  }

  [_rackView popTilesIn];
}

- (void)viewDidAppear:(BOOL)animated {
  __weak id weakSelf = self;

  if (!_seenMostRecentTurnDescription && [_match currentUserPlayerNumber] == _match.currentPlayerNumber) {
    self.seenMostRecentTurnDescription = YES;

    [self showHUDWithActivity:NO caption:[_match mostRecentTurnDescription]];
    [self makeHUDNonModal];  // Can get annoying if you just want to get going.

    [self performBlock:^(id sender) {
      [weakSelf hideActivityHUD];
    } afterDelay:1.5];

    [[LQAudioManager sharedManager] playEffect:kEffectNewGame];

    [self highlightLettersPlayedByOpponentInMostRecentTurn];
  }

  [_boardScrollView.boardView updateTilesRemainingLabelFromMatch:_match];

  [super viewDidAppear:animated];
}

- (void)setViewState:(int)newViewState {
  if (_viewState == newViewState)
    return;

  switch (_viewState) {
    case kViewStateNormal:       [self leaveNormalState];       break;
    case kViewStateSwap:         [self leaveSwapState];         break;
    case kViewStateEnded:        [self leaveGameOverState];     break;
    case kViewStateBlankChooser: [self leaveBlankChooserState]; break;
    default: break;
  }

  _viewState = newViewState;

  switch (_viewState) {
    case kViewStateNormal:       [self enterNormalState];       break;
    case kViewStateSwap:         [self enterSwapState];         break;
    case kViewStateEnded:        [self enterGameOverState];     break;
    case kViewStateBlankChooser: [self enterBlankChooserState]; break;
    default: break;
  }
}

- (void)enterNormalState {
  _rackView.hidden = NO;
  _endedLabel.hidden = YES;
  _submitButton.hidden = NO;
  _swapButton.hidden = NO;
  _shuffleButton.hidden = NO;
  _chatButton.hidden = NO;
  _swapInfoView.hidden = YES;

  _boardScrollView.userInteractionEnabled = YES;
  _rackView.userInteractionEnabled = YES;
}

- (void)leaveNormalState {
}


- (void)goBack {
  if (_viewState == kViewStateSwap) {
    self.viewState = kViewStateNormal;
  } else {
    [super goBack];
  }
}

- (void)match:(Match *)match turnDidHappen:(Turn *)turn {
  DLog(@"match turn did happen: type=%d", turn.type);

  [_boardScrollView.boardView updateTilesRemainingLabelFromMatch:_match];

  if (turn.matchState == kMatchStateEndedDeclined) {
    // rejection of pending match has been saved. it's ok to go back now.
    // if we had gone back immediately, the "your turn" would potentially show
    // this match still since it could've refreshed before the rejected match was saved.

    [self goBack];
    return;
  }

  [self updateScoreboard];
  [self updateScoreboardTiles];

  if (match.state == kMatchStateEndedNormal ||
      match.state == kMatchStateEndedResign) {

    [self handleMatchEnded];
    return;
  }

  if (turn.type == kTurnTypePlay)
    [self handlePlayTurn:turn];

  if (_chatVC) {
    [_chatVC refresh];
  } else if (!_match.passAndPlay) {
    [self addChatButton];
    self.chatVC = [ChatViewController controllerForMatch:_match delegate:self];
  }

  if (_match.passAndPlay) {
    float delay = turn.type == kTurnTypePlay ? 3.5 : 0.1;

    __weak id weakSelf = self;
    __weak id weakMatch = _match;
    __weak id weakRack = _rackView;

    [self performBlock:^(id sender) {
      [weakRack popTilesOut];

      NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Please pass the device to %@.", nil),
                           [[weakMatch currentUserPlayer] usernameForDisplay]];

      [weakSelf showAlertWithCaption:message
                              titles:@[ @"OK" ]
                              colors:@[ kGlossyBlackColor ]
                               block:^(int buttonPressed) {
                                 [weakSelf setupRack];
                                 [weakRack popTilesIn];
                                 [weakSelf hideActivityHUD];

                                 if ([weakSelf match].passAndPlay) {
                                   [weakSelf highlightLettersPlayedByOpponentInMostRecentTurn];
                                 }

                                 [weakSelf performBlock:^(id sender) {
                                   [weakSelf zoomToLettersOwnedByCurrentPlayer];
                                 } afterDelay:2];
                               }];
    } afterDelay:delay];   // Let score show in HUD for a bit.
  } else {
    [self setupRack];
  }

  [self performBlock:^(id sender) {
    [_boardScrollView zoomOut];
  } afterDelay:0.75];
}

- (void)matchWillSaveRemotely:(Match *)match {
  [self showHUDWithActivity:YES caption:NSLocalizedString(@"Sending ...", nil)];
}

- (void)matchDidSaveRemotely:(Match *)match success:(BOOL)success {
  [self hideActivityHUD];

  if (!success) {
    // Pretty much the only reason this could fail is a network issue.
    [self handleTimeout:nil];
  }
}

- (void)handlePlayTurn:(Turn *)turn {
  [self displayScoreChangeMessage:turn];
  [self changeHighlightedLettersToNormal];

  [[LQAudioManager sharedManager] playEffect:kEffectPlayedWord];

  [TestFlight passCheckpoint:@"matchPlayedWord"];
}

- (void)displayScoreChangeMessage:(Turn *)turn {
  NSString *caption;

  if (turn.playerNumber == [_match currentUserPlayerNumber] || _match.passAndPlay) {
    NSString *opponentName = [[_match opponentPlayer] usernameForDisplay];
    caption = [NSString stringWithFormat:NSLocalizedString(@"You scored %d points this turn! 😃", nil), turn.scoreDelta, opponentName];
  } else {
    NSString *opponentName = [[_match opponentPlayer] usernameForDisplay];
    caption = [NSString stringWithFormat:NSLocalizedString(@"%@ scored %d points", nil), opponentName, turn.scoreDelta];
  }

  [self showHUDWithActivity:NO caption:caption];
  [self performBlock:^(id sender) {
    [self hideActivityHUD];
  } afterDelay:2];
}

- (void)changeHighlightedLettersToNormal {
  [self performBlock:^(id sender) {
    for (UIView *subview in _boardScrollView.boardView.subviews) {
      if ([subview isKindOfClass:[TileView class]]) {
        TileView *tileView = (TileView *)subview;
        if (tileView.letter.turnNumber == -1) {
          tileView.letter = [_match letterAtCellIndex:tileView.letter.cellIndex];
          [tileView fadeIn:0.4 delegate:nil];
        }
      }
    }
  } afterDelay:2.5];
}

float squaredDistance(float x1, float y1, float x2, float y2) {
  return (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
}

- (NSArray *)lettersOwnedByPlayer:(int)playerNumber {
  return [_boardScrollView.boardView.subviews select:^BOOL(id subview) {
    if ([subview isKindOfClass:[TileView class]]) {
      TileView *tileView = (TileView *)subview;
      return (tileView.letter.playerOwner == playerNumber);
    }
    return NO;
  }];
}

- (NSArray *)lettersPlayedByOpponentInMostRecentTurn {
  return [_boardScrollView.boardView.subviews select:^BOOL(id subview) {
    if ([subview isKindOfClass:[TileView class]]) {
      TileView *tileView = (TileView *)subview;
      return (tileView.letter.turnNumber == _match.turns.count);
    }
    return NO;
  }];
}

- (NSArray *)allLetters {
  return [_boardScrollView.boardView.subviews select:^BOOL(id subview) {
    return [subview isKindOfClass:[TileView class]];
  }];
}

- (void)highlightLettersPlayedByOpponentInMostRecentTurn {
  [self performBlock:^(id sender) {
    [[self allLetters] each:^(TileView *tileView) {
      tileView.letter = [_match letterAtCellIndex:tileView.letter.cellIndex];
      tileView.isNew = NO;
    }];

    __block NSTimeInterval delay = 0;

    [[self lettersPlayedByOpponentInMostRecentTurn] each:^(TileView *tileView) {
      tileView.letter = [_match letterAtCellIndex:tileView.letter.cellIndex];
      tileView.isNew = YES;
      [tileView jumpWithDelay:delay repeat:NO];
      delay += 0.1;
    }];
  } afterDelay:1.33];
}

- (BOOL)shouldDisplayBackgroundBoardImage {
  return NO;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
  if (scrollView == _boardScrollView)
    return _boardScrollView.boardView;
  return nil;
}

// Note: must be implemented for zooming to work.

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
  DLog(@"done zooming");

  _boardScrollView.userInteractionEnabled = YES;

  if (_boardScrollView.zoomScale > _boardScrollView.minimumZoomScale)
    [_boardScrollView onZoomIn];
  else
    [_boardScrollView onZoomOut];
}

- (BOOL)draggableViewCanBeDragged:(DraggableView *)draggableView {
  if (_match.state != kMatchStateActive &&
      _match.state != kMatchStatePending)
    return NO;

  BOOL isTile = ([draggableView isKindOfClass:[TileView class]]);

  if (!isTile)
    return NO;

  TileView *tileView = (TileView *)draggableView;

  // empty slot in rack

  if (tileView.hidden)
    return NO;

  // Player can reorder their rack at any time (their turn or not).

  if (tileView.letter.rackIndex != -1)
    return YES;

  // Tiles on the board can only be dragged by their owners when it is their turn
  // and they placed the tile there this turn.

  Letter *letter = [_match letterAtCellIndex:tileView.letter.cellIndex];

  if (_match.passAndPlay)
    return (letter.turnNumber == -1 && _match.currentPlayerNumber == letter.playerOwner);

  return (letter.playerOwner == [_match currentUserPlayerNumber] &&
          _match.currentPlayerNumber == [_match currentUserPlayerNumber] &&
          letter.turnNumber == -1);
}

- (void)draggableViewDidStartDragging:(DraggableView *)draggableView {
  DLog(@"------ begin dragging operation.");

  BOOL isTile = ([draggableView isKindOfClass:[TileView class]]);

  if (!isTile)
    return;

  TileView *tileView = (TileView *)draggableView;

  if (tileView.letter.rackIndex != -1) {
    DLog(@"started dragging tile from rack slot %d", tileView.letter.rackIndex);
  } else {
    DLog(@"started dragging tile from board at (%d, %d)", cellX(tileView.letter.cellIndex), cellY(tileView.letter.cellIndex));
  }

  [tileView makeProxyForDraggingInView:self.view];

  // Tiles already on the board that's being dragged should be hidden
  // when the drag proxy is being dragged around.

  //  tileView.hidden = (tileView.letter.cellIndex != -1);
  tileView.alpha = 0.02;
}

- (BOOL)isDropOnRack:(CGPoint)point {
  return CGRectContainsPoint(_rackView.frame, CGPointMake(point.x, point.y+kDragProxyFingerOffset/2));
}

- (int)rackSlotForPoint:(CGPoint)point {
  CGFloat rackCellWidth = CGRectGetWidth(_rackView.bounds) / kRackTileCount;
  int targetRackIndex = (point.x - CGRectGetMinX(_rackView.frame)) / rackCellWidth;
  return MAX(0, MIN(targetRackIndex, kRackTileCount - 1));
}

- (BOOL)tileView:(TileView *)tileView wasDroppedOnRackAtPoint:(CGPoint)point  {
  int targetRackIndex = [self rackSlotForPoint:point];

  DLog(@"dropped tile on rack at slot %d", targetRackIndex);

  Letter *sourceLetter;

  // If dragged from rack, get source letter from rack.
  // Else dragged from board, get source letter from board.

  if (tileView.letter.rackIndex != -1) {
    sourceLetter = [[_match rackForCurrentUser] objectAtIndex:tileView.letter.rackIndex];
  } else {
    sourceLetter = [_match letterAtCellIndex:tileView.letter.cellIndex];
  }

  NSAssert(sourceLetter != nil, @"expected existing source letter item");

  BOOL wasOnTheBoard = (sourceLetter.cellIndex != -1);

  if (![_match moveLetter:sourceLetter toRackAtIndex:targetRackIndex])
    return NO;

  if (wasOnTheBoard)
    [tileView removeFromSuperview];

  [self setupRack];

  return YES;
}

- (BOOL)tileView:(TileView *)tileView wasDroppedOnBoardAtPoint:(CGPoint)point {
  point = [self.boardScrollView.boardView convertPoint:point fromView:self.view];

  CGPoint boardCell = [_boardScrollView.boardView boardToCell:point];

  if (boardCell.x < 0 || boardCell.y < 0)
    return NO;

  CGRect cellRect = [_boardScrollView.boardView boardFromCellX:boardCell.x y:boardCell.y];

  DLog(@"dropped tile on board cell (%d, %d)", (int)boardCell.x, (int)boardCell.y);

  [[LQAudioManager sharedManager] playEffect:kEffectTilePlaced];

  // Came from the rack?

  if (tileView.letter.rackIndex != -1) {
    BOOL ok = [self tileView:tileView wasDraggedFromRackToBoardCell:boardCell cellRect:cellRect];

    if (ok)
      [self setupRack];

    return ok;
  }

  // No, came from the board.

  return [self tileView:tileView wasDraggedFromBoardToBoardCell:boardCell cellRect:cellRect];
}

- (int)adjustedCellIndexForLetterAtCellIndex:(int)cellIndex rect:(CGRect *)adjustedRect {
  if (![_match letterAtCellIndex:cellIndex])
    return cellIndex;

  DLog(@"there is already a letter present; looking for nearby (NE/SE/SW/NW) empty cell...");

  int x = cellX(cellIndex);
  int y = cellY(cellIndex);

  int E = x+1;
  int S = y+1;
  int N = y-1;
  int W = x-1;

  int NE = cellIndexFor(E, N);
  int SE = cellIndexFor(E, S);
  int SW = cellIndexFor(W, S);
  int NW = cellIndexFor(W, N);

  if      (isValidCell(E, N) && ![_match letterAtCellIndex:NE]) cellIndex = NE;
  else if (isValidCell(E, S) && ![_match letterAtCellIndex:SE]) cellIndex = SE;
  else if (isValidCell(W, S) && ![_match letterAtCellIndex:SW]) cellIndex = SW;
  else if (isValidCell(W, N) && ![_match letterAtCellIndex:NW]) cellIndex = NW;

  *adjustedRect = [_boardScrollView.boardView boardFromCellX:cellX(cellIndex) y:cellY(cellIndex)];

  return cellIndex;
}

- (BOOL)tileView:(TileView *)tileView wasDraggedFromRackToBoardCell:(CGPoint)boardCell cellRect:(CGRect)cellRect {
  int dstCellIndex = cellIndexFor(boardCell.x, boardCell.y);
  int cellIndex = [self adjustedCellIndexForLetterAtCellIndex:dstCellIndex rect:&cellRect];

  Letter *letter = [[_match rackForCurrentUser] objectAtIndex:tileView.letter.rackIndex];

  int rackIndexBefore = letter.rackIndex;

  if (![_match moveLetter:letter toBoardAtCellIndex:cellIndex])
    return NO;

  // If the letter dropped was a blank, have the user choose a substitute letter.

  __weak id weakSelf = self;

  TileChooserCallback continueWithLetter = ^(int letterValue) {
    if (letterValue >= 'A' && letterValue <= 'Z') {
      letter.substituteLetter = letterValue;

      TileView *boardTileView = [TileView viewWithFrame:cellRect letter:letter];
      [boardTileView configureForBoardDisplay];
      boardTileView.dragDelegate = self;
      [_boardScrollView.boardView addSubview:boardTileView];

      [weakSelf performBlock:^(id sender) {
        [weakSelf zoomToLettersPlacedInThisTurn];
      } afterDelay:0.5];
    } else {
      [_match moveLetter:letter toRackAtIndex:rackIndexBefore];
      [weakSelf setupRack];
    }
  };

  if (letter.letter == ' ') {
    [self showBlankChooserWithCallback:continueWithLetter];
  } else {
    continueWithLetter(letter.letter);
  }

  return YES;
}

- (BOOL)tileView:(TileView *)tileView wasDraggedFromBoardToBoardCell:(CGPoint)dstBoardCell cellRect:(CGRect)toCellRect {
  NSAssert(tileView.letter.cellIndex >= 0 && tileView.letter.cellIndex < kBoardCellCount, @"invalid board-to-board source");

  int fromCellIndex = tileView.letter.cellIndex;
  int toCellIndex = cellIndexFor(dstBoardCell.x, dstBoardCell.y);
  if (fromCellIndex != toCellIndex)
    toCellIndex = [self adjustedCellIndexForLetterAtCellIndex:toCellIndex rect:&toCellRect];

  DLog(@"drag from board at (%d, %d) to board at (%d, %d)",
       cellX(tileView.letter.cellIndex), cellY(tileView.letter.cellIndex),
       cellX(toCellIndex), cellY(toCellIndex));

  Letter *sourceLetter = [_match letterAtCellIndex:tileView.letter.cellIndex];
  NSAssert(sourceLetter != nil, @"missing letter on the board");

  __weak id weakSelf = self;

  TileChooserCallback continueWithLetter = ^(int letterValue) {
    tileView.alpha = 1;

    if (letterValue >= 'A' && letterValue <= 'Z') {
      sourceLetter.substituteLetter = letterValue;

      tileView.letter = sourceLetter;
      tileView.frame = toCellRect;

      [weakSelf performBlock:^(id sender) {
        [weakSelf zoomToLettersPlacedInThisTurn];
      } afterDelay:0.5];
    }
  };

  if (tileView.letter.cellIndex == toCellIndex && sourceLetter.letter == ' ') {
    DLog(@"drop in-place => change the substitute letter of this blank tile");
    [self showBlankChooserWithCallback:continueWithLetter];
    return YES;
  }

  if (![_match moveLetter:sourceLetter toBoardAtCellIndex:toCellIndex])
    return NO;

  tileView.letter.cellIndex = toCellIndex;
  tileView.letter.rackIndex = -1;

  if (sourceLetter.letter == ' ') {
    [self showBlankChooserWithCallback:continueWithLetter];
  } else {
    tileView.frame = toCellRect;
    tileView.alpha = 1;

    [self zoomToLettersPlacedInThisTurn];
  }

  return YES;
}

- (BOOL)draggableView:(DraggableView *)draggableView wasDroppedAtPoint:(CGPoint)point {
  if (![draggableView isKindOfClass:[TileView class]]) {
    DLog(@"------ end dragging operation: not tile view");
    return NO;
  }

  TileView *tileView = (TileView *)draggableView;

  [self removeDropTargetView];

  if ([self isDropOnRack:point]) {
    DLog(@"------ end dragging operation: dropped on rack");
    return [self tileView:tileView wasDroppedOnRackAtPoint:point];
  }

  // While any player can update their rack at any time, the local user
  // may only drag onto the board if it's their turn.
  // The change doesn't "stick" but ...

  if (!_match.passAndPlay && ![_match currentUserIsCurrentPlayer]) {
    DLog(@"------ end dragging operation: not your turn");
    [self showNotYourTurnError];
    [self setupRack];
    return NO;
  }

  DLog(@"------ end dragging operation: dropped on board");
  BOOL ok = [self tileView:tileView wasDroppedOnBoardAtPoint:point];

  if (!ok)
    tileView.alpha = 1;

  return ok;
}

- (void)draggableViewTouchesWereCanceled:(DraggableView *)draggableView {
  if (![draggableView isKindOfClass:[TileView class]]) {
    DLog(@"------ end dragging operation: not tile view");
    return;
  }

  DLog(@"------ end dragging operation: touches canceled");
  TileView *tileView = (TileView *)draggableView;
  tileView.alpha = 1;
}

- (void)removeDropTargetView {
  [[_boardScrollView.boardView viewWithTag:kDropTargetViewTag] removeFromSuperview];
}

- (void)draggableViewIsBeingDragged:(DraggableView *)draggableView currentPoint:(CGPoint)point {
  if (![draggableView isKindOfClass:[TileView class]])
    return;

  [self removeDropTargetView];

  if ([self isDropOnRack:point]) {
    _rackView.layer.borderColor = kTileDropHighlightColor.CGColor;
    _rackView.layer.borderWidth = SCALED(2);
    return;
  }

  _rackView.layer.borderWidth = 0;

  point = [self.boardScrollView.boardView convertPoint:point fromView:self.view];

  CGPoint boardCell = [_boardScrollView.boardView boardToCell:point];

  if (boardCell.x < 0 || boardCell.y < 0)
    return;

  CGRect cellRect = [_boardScrollView.boardView boardFromCellX:boardCell.x y:boardCell.y];

//  DLog(@"hover tile atop board cell (%d, %d)", (int)boardCell.x, (int)boardCell.y);

  TileView *tempView = [TileView viewWithFrame:cellRect letter:0];
  [tempView configureForBoardDisplayAsPlaceholder];
  tempView.tag = kDropTargetViewTag;
  [_boardScrollView.boardView addSubview:tempView];
  tempView.userInteractionEnabled = NO;
}

- (void)draggableViewWasTouched:(DraggableView *)draggableView {
  if (![draggableView isKindOfClass:[TileView class]])
    return;

  TileView *tileView = (TileView *)draggableView;

  NSLog(@"tile view touched: board=%d, rack=%d", tileView.letter.cellIndex, tileView.letter.rackIndex);
}

- (CGRect)boundingRectForLetters:(NSArray *)letters {
  if (letters.count == 0)
    return CGRectZero;

  __block CGRect bounds;

  [letters enumerateObjectsUsingBlock:^(Letter *aLetter, NSUInteger idx, BOOL *stop) {
    UIView *tileView = nil;

    for (UIView *subview in _boardScrollView.boardView.subviews) {
      if ([subview isKindOfClass:[TileView class]]) {
        TileView *aTileView = (TileView *)subview;
        if (aTileView.letter.cellIndex == aLetter.cellIndex) {
          tileView = aTileView;
          break;
        }
      }
    }

    if (idx == 0)
      bounds = tileView.frame;
    else
      bounds = CGRectUnion(bounds, tileView.frame);
  }];

  return bounds;
}

- (CGRect)boundingRectForLettersOwnedByCurrentPlayer {
  CGRect bounds = [self boundingRectForLetters:[_match lettersOwnedByPlayerNumber:_match.currentPlayerNumber]];
  if (bounds.size.width == 0) {
    int index = _match.currentPlayerNumber == 0 ? kStartCellIndexForFirstPlayer : kStartCellIndexForSecondPlayer;
    return [_boardScrollView.boardView boardFromCellX:cellX(index) y:cellY(index)];
  }
  return bounds;
}

- (CGRect)boundingRectForLettersPlacedThisTurn {
  return [self boundingRectForLetters:[_match lettersOnBoardPlacedInCurrentTurn]];
}

- (CGRect)boundingRectForAllLetters {
  return [self boundingRectForLetters:[_match allLetters]];
}

- (void)zoomToLettersPlacedInThisTurn {
  CGRect boundsForAll = [self boundingRectForLettersPlacedThisTurn];
  [self.boardScrollView zoomToRect:boundsForAll animated:YES];
}

- (void)zoomToLettersOwnedByCurrentPlayer {
  CGRect bounds = [self boundingRectForLettersOwnedByCurrentPlayer];

  CGFloat boardCellSizeUnscaled = CGRectGetWidth(self.boardScrollView.bounds) / kBoardSize;
  bounds = CGRectInset(bounds,
                       -boardCellSizeUnscaled * 1.5,
                       -boardCellSizeUnscaled * 1.5);

  [self.boardScrollView zoomToRect:bounds animated:YES];
}

- (void)zoomToAllLetters {
  CGFloat boardCellSizeUnscaled = CGRectGetWidth(self.boardScrollView.bounds) / kBoardSize;

  CGRect rect = [self boundingRectForAllLetters];

  if (rect.size.width > 0) {
    CGRect boundsForAll = CGRectInset(rect,
                                      -boardCellSizeUnscaled * 1.5,
                                      -boardCellSizeUnscaled * 1.5);

    DLog(@"zoom to %@", NSStringFromCGRect(boundsForAll));

    [self.boardScrollView zoomToRect:boundsForAll animated:YES];
  } else {
    [self.boardScrollView zoomOut];
  }
}

- (void)showNotYourTurnError {
  [TestFlight passCheckpoint:@"matchNotYourTurn"];

  [[LQAudioManager sharedManager] playEffect:kEffectError];

  NSString *caption = NSLocalizedString(@"Oops! It's not your turn. 😞",
                                        @"Player tries to perform unauthorized gameplay action; you can remove the Emoji icon of course.");

  [self showHUDWithActivity:NO caption:caption];

  __weak id weakSelf = self;
  [self performBlock:^(id sender) {
    [weakSelf hideActivityHUD];
  } afterDelay:1.5];
}

- (void)enterBlankChooserState {
  _rackView.hidden = YES;
  _endedLabel.hidden = YES;
  _submitButton.hidden = YES;
  _chatButton.hidden = YES;
  _shuffleButton.hidden = YES;
  _swapButton.hidden = YES;
  _swapInfoView.hidden = YES;

  _boardScrollView.userInteractionEnabled = NO;
  _rackView.userInteractionEnabled = NO;
}

- (void)leaveBlankChooserState {
}

- (void)showBlankChooserWithCallback:(TileChooserCallback)completion {
  TileChooserView *chooser = [TileChooserView view];

  __weak id weakChooser = chooser;
  __weak id weakSelf = self;

  TileChooserCallback callback = ^(int letter) {
    [weakSelf setViewState:kViewStateNormal];

    completion(letter);

    [weakChooser popOut:0.3 delegate:nil];

    [weakSelf performBlock:^(id sender) {
      [weakChooser removeFromSuperview];
    } afterDelay:0.4];
  };

  chooser.callback = callback;

  self.viewState = kViewStateBlankChooser;

  [self.view addSubview:chooser];
  chooser.center = self.view.center;
  [chooser popIn:0.4 delegate:nil];

  // Show a tip (once).

  NSString * const kHasSeenBlankChooserTip = @"hasSeenBlankChooserTip";
  if ([[NSUserDefaults standardUserDefaults] boolForKey:kHasSeenBlankChooserTip] == NO) {
    [weakSelf performBlock:^(id sender) {
      [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasSeenBlankChooserTip];
      [weakSelf showHUDWithActivity:NO caption:NSLocalizedString(@"Pick a letter for the blank tile", nil)];
    } afterDelay:0.6];

    [weakSelf performBlock:^(id sender) {
      [weakSelf hideActivityHUD];
    } afterDelay:1+0.6];
  }
}

- (void)handleMatchEnded {
  if (_match.state == kMatchStateEndedDeclined) {
    [self goBack];
    return;
  }

  [self performBlock:^(id sender) {
    self.viewState = kViewStateEnded;
  } afterDelay:1];

}

- (void)enterGameOverState {
  [self.boardScrollView zoomOut];

  _rackView.hidden = YES;
  _endedLabel.hidden = NO;
  _submitButton.hidden = YES;
  _chatButton.hidden = YES;
  _shuffleButton.hidden = YES;
  _swapButton.hidden = YES;
  _swapInfoView.hidden = YES;

  BOOL isTie = (_match.winningPlayer == -1 && _match.losingPlayer == -1);
  BOOL currentPlayerWon = (_match.winningPlayer == [_match currentUserPlayerNumber] && !isTie);

  // Loser gets to rematch or in PNP matches, whomever is holding the device...
  BOOL showRematchOption = !currentPlayerWon || _match.passAndPlay;

  NSString *caption;
  if (currentPlayerWon) {
    caption = NSLocalizedString(@"YOU WON THE MATCH!", nil);
    [[LQAudioManager sharedManager] playEffect:kEffectEndWon];
    [TestFlight passCheckpoint:@"matchWon"];
  } else {
    if (isTie) {
      caption = NSLocalizedString(@"It's a tie!", nil);
      [TestFlight passCheckpoint:@"matchTied"];
    } else {
      NSString *winnerName = [[_match winner] usernameForDisplay];
      caption = [NSString stringWithFormat:NSLocalizedString(@"%@ won! Rematch?", nil), winnerName];
      [TestFlight passCheckpoint:@"matchLost"];
    }
    [[LQAudioManager sharedManager] playEffect:kEffectEndLost];
  }

  UILabel *summaryLabel = [[UILabel alloc] initWithFrame:_rackView.frame];
  summaryLabel.font = [UIFont fontWithName:kFontName size:kFontSizeHeader];
  summaryLabel.lineBreakMode = UILineBreakModeWordWrap;
  summaryLabel.numberOfLines = 3;
  summaryLabel.textColor = [UIColor whiteColor];
  summaryLabel.backgroundColor = _match.winningPlayer == 0 ? kTileColorPlayerOne : _match.winningPlayer == 1 ? kTileColorPlayerTwo : [UIColor brownColor];
  summaryLabel.shadowColor = [UIColor darkGrayColor];
  summaryLabel.shadowOffset = CGSizeMake(0, 1);
  summaryLabel.text = caption;
  summaryLabel.tag = kMatchEndSummaryLabelTag;
  summaryLabel.textAlignment = UITextAlignmentCenter;
  summaryLabel.layer.cornerRadius = 8;
  summaryLabel.hidden = YES;
  [[self.view viewWithTag:kMatchEndSummaryLabelTag] removeFromSuperview];
  [self.view addSubview:summaryLabel];

  if (showRematchOption) {
    [[self.view viewWithTag:kMatchEndRematchButtonTag] removeFromSuperview];
    CGRect rematchFrame = CGRectMake(0, CGRectGetMinY(_rackView.frame),
                                     CGRectGetWidth(self.view.bounds),
                                     CGRectGetHeight(self.view.bounds) - CGRectGetMinY(_rackView.frame));
    UIButton *rematchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rematchButton.tag = kMatchEndRematchButtonTag;
    rematchButton.frame = rematchFrame;
    rematchButton.backgroundColor = [UIColor clearColor];
    [rematchButton addTarget:self action:@selector(doRematch:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:rematchButton];
  }

  if (currentPlayerWon) {
    NSArray *playerLetters = [self lettersOwnedByPlayer:_match.currentPlayerNumber];

    [self performBlock:^(id sender) {
      [summaryLabel popIn:0.4 delegate:nil];

      [self performBlock:^(id sender) {
        ExplosionView *boomView = [ExplosionView new];
        [self.view.window addSubview:boomView];
        [boomView explodeFromPoint:self.view.window.center completion:^{
          [UIView animateWithDuration:0.4 animations:^{
            boomView.alpha = 0;
          } completion:^(BOOL finished) {
            [boomView removeFromSuperview];
          }];
        }];
      } afterDelay:playerLetters.count * 0.1];

      __block NSTimeInterval delay = 0;
      [playerLetters each:^(TileView *tileView) {
        tileView.letter = [_match letterAtCellIndex:tileView.letter.cellIndex];
        tileView.isNew = NO;
        [tileView jumpWithDelay:delay repeat:YES];
        delay += 0.15;
      }];      
    } afterDelay:2.5];

    _boardScrollView.clipsToBounds = NO;
  }
}

- (void)leaveGameOverState {
  [[self.view viewWithTag:kMatchEndRematchButtonTag] removeFromSuperview];
  [[self.view viewWithTag:kMatchEndSummaryLabelTag] removeFromSuperview];
}

- (void)doRematch:(id)sender {
  [TestFlight passCheckpoint:@"matchRematched"];

  AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  if (_match.passAndPlay) {
    [appDelegate loadPassAndPlayMatch];
  } else {
    Match *match = [[Match alloc] initWithPlayer:[PFUser currentUser] player:[_match opponentPlayer]];
    [appDelegate replaceTopViewControllerForMatch:match];
  }
}

- (CAAnimation *)shakeAnimation {
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
  animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeRotation(-3 * M_PI/180.0, 0, 0, 1.0)];
  animation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeRotation(3 * M_PI/180.0, 0, 0, 1.0)];
  animation.autoreverses = YES;
  animation.duration = 0.5;
  animation.repeatCount = HUGE_VALF;
  return animation;
}

- (void)appBecameActive:(NSNotification *)notification {
  if (!_match.currentUserIsCurrentPlayer && self.navigationController.topViewController == self) {
    DLog(@"app became active and it's not your turn and we're on top -- reload!");

    __weak id weakNav = self.navigationController;
    PFQuery *query = [PFQuery queryWithClassName:@"Match"];
    [query getObjectInBackgroundWithId:_match.matchID block:^(PFObject *object, NSError *error) {
      if (error) {
        [error showParseError:NSLocalizedString(@"fetch match info", @"Activity indicator")];
        return;        
      }

      [Match matchWithExistingMatchObject:object block:^(Match *aMatch, NSError *error) {
        if (error) {
          [error showParseError:NSLocalizedString(@"fetch match info", @"Activity indicator")];
        } else {
          dispatch_async(dispatch_get_main_queue(), ^{
            if ([[weakNav topViewController] isKindOfClass:[MatchViewController class]])
              [weakNav popViewControllerAnimated:NO];
            [weakNav pushViewController:[MatchViewController controllerWithMatch:aMatch] animated:NO];
          });
        }
      }];
    }];
  }
}

- (BOOL)canBecomeFirstResponder {
  return YES;
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
  DLog(@"shook device");

  NSArray *currentLetters = [_match lettersOnBoardPlacedInCurrentTurn];

  if (currentLetters.count > 0) {
    [TestFlight passCheckpoint:@"matchRecalledLetters"];
    [self recall];
  } else {
    [self doShuffle:self];
  }
}

- (void)recall {
  NSArray *currentLetters = [_match lettersOnBoardPlacedInCurrentTurn];

  if (currentLetters.count > 0) {
    [currentLetters enumerateObjectsUsingBlock:^(Letter *letter, NSUInteger idx, BOOL *stop) {
      for (UIView *subview in _boardScrollView.boardView.subviews) {
        if ([subview isKindOfClass:[TileView class]]) {
          TileView *tileView = (TileView *)subview;
          if (tileView.letter.cellIndex == letter.cellIndex) {
            [tileView removeFromSuperview];
          }
        }
      }
    }];

    [_match recallLettersPlacedInCurrentTurn];
    [self setupRack];
    [self zoomToLettersOwnedByCurrentPlayer];
  }
}

@end
