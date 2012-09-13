#import "Match.h"
#import "WordList.h"
#import "Word.h"
#import "Letter.h"
#import "Turn.h"
#import "BoardUtil.h"

@interface Match ()

@property (nonatomic, readwrite) int state;

@property (nonatomic, readwrite, strong) PFUser *firstPlayer;
@property (nonatomic, readwrite, strong) PFUser *secondPlayer;

@property (nonatomic, readwrite) int currentPlayerNumber;

@property (nonatomic, readwrite, assign) int winningPlayer;
@property (nonatomic, readwrite, assign) int losingPlayer;

@property (nonatomic, readwrite) int scoreForFirstPlayer;
@property (nonatomic, readwrite) int scoreForSecondPlayer;

@property (nonatomic, copy, readwrite) NSString *chatThreadID;

@end

@implementation Match {
  PFObject *_match;
  NSMutableArray *_rackForFirstPlayer;
  NSMutableArray *_rackForSecondPlayer;
  NSMutableArray *_bag;
  NSMutableDictionary *_board;
  NSMutableArray *_turns;
  int _scoreDelta;
}

- (id)initWithPlayer:(PFUser *)player1 player:(PFUser *)player2 {
  self = [super init];

  if (self) {
    _state = kMatchStatePending;

    _firstPlayer = player1;
    _secondPlayer = player2;

    _match = [[PFObject alloc] initWithClassName:@"Match"];

    // We may have instances wherein we add one player initially then find an opponent later.

    if (_firstPlayer)
      [_match setObject:_firstPlayer forKey:@"firstPlayer"];

    if (_secondPlayer)
      [_match setObject:_secondPlayer forKey:@"secondPlayer"];

    _winningPlayer = _losingPlayer = -1;

    // See Texts/Tiles.txt

    NSDictionary *tileDistribution = @{
    @'A':@12, @'B':@2, @'C':@2, @'D':@6, @'E':@8,
    @'F':@2, @'G':@4, @'H':@5, @'I':@10, @'J':@1,
    @'K':@1, @'L':@5, @'M':@2, @'N':@6, @'O':@10,
    @'P':@2, @'Q':@1, @'R':@8, @'S':@6, @'T':@9,
    @'U':@5, @'V':@2, @'W':@2, @'X':@1, @'Y':@2,
    @'Z':@1, @' ':@4,
#if DEBUG
    @(kBombLetter):@20
#else
    @(kBombLetter):@3
#endif
    };

    // Bag is just a shuffled, flattened array of letters.

    _bag = [NSMutableArray arrayWithCapacity:105];

    [tileDistribution enumerateKeysAndObjectsUsingBlock:^(NSNumber *letterValue, NSNumber *letterCount, BOOL *stop) {
      for (int i = 0; i < letterCount.integerValue; ++i)
        [_bag addObject:letterValue];
    }];

    _bag = [[_bag shuffledArray] mutableCopy];

    _board = [NSMutableDictionary dictionaryWithCapacity:kBoardCellCount];

    _rackForFirstPlayer = [NSMutableArray arrayWithCapacity:kRackTileCount];
    _rackForSecondPlayer = [NSMutableArray arrayWithCapacity:kRackTileCount];

    [self fillRackOfPlayer:0];
    [self fillRackOfPlayer:1];

    _turns = [NSMutableArray array];
  }

  return self;
}

+ (id)matchWithExistingMatchObject:(PFObject *)matchObject
                             block:(DecodeMatchCompletionBlock)block {

  Match *aMatch = [[Match alloc] init];

  if (aMatch) {
    [aMatch decodeAllFrom:matchObject block:block];
  }

  return aMatch;
}

+ (id)matchWithRandomOpponentCompletion:(PFBooleanResultBlock)block {
  Match *aMatch = [[Match alloc] initWithPlayer:nil player:[PFUser currentUser]];

  if (aMatch) {
    [aMatch->_match setBool:YES forKey:@"setupRandom"];
    [aMatch saveMatch:block];
  }

  return aMatch;
}

#pragma mark - serialization

// Parse Backend <=> PFObject <=> Match object (property access) <=> rest of the app
// We store a single PFObject on Parse for the entire logical match.
// Entities like board state, racks, letters, etc are stored as dictionaries and arrays on Parse,
// but in the app, they are full Objective-C objects.

- (NSDictionary *)encodeLetter:(id)aLetter {
  if (aLetter == [NSNull null])
    return [NSDictionary dictionary];

  Letter *letter = aLetter;

  return [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInt:letter.cellIndex], @"cellIndex",
          [NSNumber numberWithInt:letter.rackIndex], @"rackIndex",
          [NSNumber numberWithInt:letter.playerOwner], @"player",
          [NSNumber numberWithInt:letter.turnNumber], @"turn",
          [NSNumber numberWithInt:letter.letter], @"letter",
          [NSNumber numberWithInt:letter.substituteLetter], @"substituteLetter",
          nil];
}

- (id)decodeLetter:(NSDictionary *)letterDict {
  if (letterDict.count == 0)
    return [NSNull null];

  Letter *letter = [Letter new];
  letter.cellIndex = [letterDict intForKey:@"cellIndex"];
  letter.rackIndex = [letterDict intForKey:@"rackIndex"];
  letter.playerOwner = [letterDict intForKey:@"player"];
  letter.turnNumber = [letterDict intForKey:@"turn"];
  letter.letter = [letterDict intForKey:@"letter"];
  letter.substituteLetter = [letterDict intForKey:@"substituteLetter"];
  return letter;
}

// input: cell(NSNumber) => Letter
// output: cell(NSString) => NSDictionary (encoded Letter)

- (NSDictionary *)encodeBoard:(NSMutableDictionary *)board {
  // JSON cannot have numeric keys so convert keys to strings.

  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:board.count];

  for (NSNumber *key in board) {
    Letter *letter = [board objectForKey:key];
    [dict setObject:[self encodeLetter:letter] forKey:[key stringValue]];
  }

  return [dict copy];
}

- (NSMutableDictionary *)decodeBoard:(NSDictionary *)boardDict {
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:boardDict.count];

  for (NSString *key in boardDict) {
    Letter *letter = [self decodeLetter:[boardDict objectForKey:key]];
    [dict setObject:letter forKey:[NSNumber numberWithInt:[key intValue]]];
  }

  return dict;
}

- (NSArray *)encodeRack:(NSArray *)rack {
  return [rack map:^id(Letter *letter) {
    return [self encodeLetter:letter];
  }];
}

- (NSMutableArray *)decodeRack:(NSArray *)itemDictArray {
  return [[itemDictArray map:^id(NSDictionary *letterDict) {
    return [self decodeLetter:letterDict];
  }] mutableCopy];
}

- (NSDictionary *)encodeTurn:(Turn *)turn {
  NSArray *wordsFormed = [NSArray array];

  if (turn.wordsFormed.count > 0) {
    wordsFormed = [turn.wordsFormed map:^id(id word) {
      if ([word isKindOfClass:Word.class])
        return [[word string] uppercaseString];
      return word;
    }];
  }

  DLog(@"encoded turn with words: %@", wordsFormed);

  NSArray *bombs = turn.bombsDetonatedAtCellIndices;
  if (!bombs) bombs = @[];

  return @{
  @"turnType": @(turn.type),
  @"player": @(turn.playerNumber),
  @"state": @(turn.matchState),
  @"wordsFormed": wordsFormed,
  @"scoreDelta": @(turn.scoreDelta),
  @"bombsDetonated": bombs
  };
}

- (Turn *)decodeTurn:(NSDictionary *)turnDict {
  Turn *turn = [Turn new];
  turn.type = [turnDict intForKey:@"turnType"];
  turn.playerNumber = [turnDict intForKey:@"player"];
  turn.matchState = [turnDict intForKey:@"state"];
  turn.wordsFormed = [turnDict objectForKey:@"wordsFormed"];
  turn.scoreDelta = [turnDict intForKey:@"scoreDelta"];
  turn.bombsDetonatedAtCellIndices = [turnDict objectForKey:@"bombsDetonated"];
  return turn;
}

- (NSArray *)encodeTurns:(NSArray *)turns {
  return [turns map:^id(Turn *turn) {
    return [self encodeTurn:turn];
  }];
}

- (NSMutableArray *)decodeTurns:(NSArray *)turnDicts {
  return [[turnDicts map:^id(NSDictionary *turnDict) {
    return [self decodeTurn:turnDict];
  }] mutableCopy];
}

- (NSString *)encodeBag:(NSMutableArray *)bag {
  NSMutableString *str = [NSMutableString stringWithCapacity:bag.count];
  [bag each:^(id sender) {
    [str appendFormat:@"%c", [sender integerValue]];
  }];
  return [str copy];
}

- (NSMutableArray *)decodeBag:(NSString *)bagStr {
  NSParameterAssert(bagStr.length < 200);
  NSMutableArray *bag = [NSMutableArray arrayWithCapacity:bagStr.length];
  for (int i=0; i<bagStr.length; ++i)
    [bag addObject:@([bagStr characterAtIndex:i])];
  return bag;
}

- (void)encodeAllTo:(id)store {
  // NB: we don't repeatedly set player1/2 since they only need to be set once.

  [store setInt:_state forKey:@"state"];
  [store setInt:_currentPlayerNumber forKey:@"currentPlayerNumber"];
  [store setInt:_winningPlayer forKey:@"winningPlayer"];
  [store setInt:_losingPlayer forKey:@"losingPlayer"];
  [store setInt:_scoreForFirstPlayer forKey:@"scoreFirstPlayer"];
  [store setInt:_scoreForSecondPlayer forKey:@"scoreSecondPlayer"];
  [store setObject:[self encodeBag:_bag] forKey:@"letterBag"];
  [store setObject:[self encodeBoard:_board] forKey:@"board"];
  [store setObject:[self encodeTurns:_turns] forKey:@"turns"];
  [store setObject:[self encodeRack:_rackForFirstPlayer] forKey:@"rackFirstPlayer"];
  [store setObject:[self encodeRack:_rackForSecondPlayer] forKey:@"rackSecondPlayer"];
}

- (void)decodeAllFrom:(id)store block:(DecodeMatchCompletionBlock)block {
  if ([store isKindOfClass:[PFObject class]]) {
    _match = store;

#if DEBUG
    DLog(@"decoding encoded match:");
    DLog(@"--------------");
    for (id key in [_match allKeys]) {
      id obj = [_match objectForKey:key];
      DLog(@"%@ = (%@) %@", key, NSStringFromClass([obj class]), obj);
    }
    DLog(@"--------------");
#endif
  }

  self.state = [store intForKey:@"state"];
  self.currentPlayerNumber = [store intForKey:@"currentPlayerNumber"];
  self.scoreForFirstPlayer = [store intForKey:@"scoreFirstPlayer"];
  self.scoreForSecondPlayer = [store intForKey:@"scoreSecondPlayer"];

  _bag = [self decodeBag:[store objectForKey:@"letterBag"]];
  _board = [self decodeBoard:[store objectForKey:@"board"]];
  _rackForFirstPlayer = [self decodeRack:[store objectForKey:@"rackFirstPlayer"]];
  _rackForSecondPlayer = [self decodeRack:[store objectForKey:@"rackSecondPlayer"]];
  _turns = [self decodeTurns:[store objectForKey:@"turns"]];

  if (self.passAndPlay) {
    if (block)
      block(nil, nil);

    return;
  }

  self.firstPlayer = [store objectForKey:@"firstPlayer"];
  self.secondPlayer = [store objectForKey:@"secondPlayer"];

  self.winningPlayer = [store intForKey:@"winningPlayer"];
  self.losingPlayer = [store intForKey:@"losingPlayer"];

  // Load data of players. First player blocks which the caller will be expecting.
  // When both player's data are loaded, call completion handler block.

  NSError *error = nil;
  [self.firstPlayer fetchIfNeeded:&error];
  if (error) {
    [error showParseError:NSLocalizedString(@"fetch player info", @"Activity indicator")];

    if (block)
      block(nil, error);

    return;
  }

  [self.secondPlayer fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
    if (error) {
      [error showParseError:NSLocalizedString(@"fetch player info", @"Activity indicator")];

      if (block)
        block(nil, error);
    } else if (block) {
      block(self, nil);
    }
  }];
}

- (void)saveMatch:(PFBooleanResultBlock)completion {
  [self encodeAllTo:_match];

#if DEBUG

  DLog(@"encoded match:");
  DLog(@"--------------");
  for (id key in [_match allKeys]) {
    id obj = [_match objectForKey:key];
    DLog(@"%@ = (%@) %@", key, NSStringFromClass([obj class]), obj);
  }
  DLog(@"--------------");

#endif

  if ([self opponentPlayer]) {
    if (![[[PFUser currentUser] objectForKey:@"opponents"] containsObject:[self opponentPlayer].objectId]) {
      [[PFUser currentUser] addUniqueObject:[self opponentPlayer].objectId forKey:@"opponents"];
      [[PFUser currentUser] saveInBackground];
    }
  }

  // Anyone can view a match but only the current player should be able to modify it.

  PFACL *matchACL = [PFACL ACL];

  // TODO Parse is fucking broken on this!
  //  [matchACL setWriteAccess:YES forUserId:[self currentPlayer].objectId];
  [matchACL setPublicWriteAccess:YES];

  [matchACL setPublicReadAccess:YES];
  _match.ACL = matchACL;

  // Parse's timeouts don't work.

  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kNetworkTimeoutDuration
                                                    target:self
                                                  selector:@selector(handleTimeout:)
                                                  userInfo:nil
                                                   repeats:NO];

  [_match saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    [timer invalidate];
    
    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"save match", nil)];
    } else {
      DLog(@"saved match to backend");
    }

    completion(succeeded, error);
  }];
}

- (void)handleTimeout:(id)sender {
  [_delegate matchDidSaveRemotely:self success:NO];
}

#pragma mark - pass and play

- (void)setPassAndPlay:(BOOL)yesNo {
  _passAndPlay = yesNo;

  if (yesNo)
    self.state = kMatchStateActive;
}

- (void)savePassAndPlayMatch {
  DLog(@"saving pnp match");

  NSMutableDictionary *store = [NSMutableDictionary dictionary];

  [self encodeAllTo:store];

  [[NSUserDefaults standardUserDefaults] setObject:store forKey:kPassAndPlayDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (id)resumablePassAndPlayMatch {
  NSDictionary *matchDict = [[NSUserDefaults standardUserDefaults] objectForKey:kPassAndPlayDefaultsKey];

  if (matchDict) {
    DLog(@"got match dict for pnp %@", matchDict);

    PFUser *player1 = [PFUser user];
    player1.username = NSLocalizedString(@"Player1", @"Name of first player for pass-and-play matches");

    PFUser *player2 = [PFUser user];
    player2.username = NSLocalizedString(@"Player2", @"Name of first player for pass-and-play matches");

    Match *aMatch = [[Match alloc] init];

    aMatch.firstPlayer = player1;
    aMatch.secondPlayer = player2;
    aMatch.passAndPlay = YES;

    [aMatch decodeAllFrom:matchDict block:nil];

    return aMatch;
  }

  return nil;
}

- (void)removePassAndPlayMatch {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPassAndPlayDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)addLetterToBoard:(Letter *)letter {
  NSNumber *cellKey = [NSNumber numberWithInt:letter.cellIndex];
  Letter *existingLetter = [_board objectForKey:cellKey];
  if (existingLetter)
    return NO;
  [_board setObject:letter forKey:cellKey];
  return YES;
}

- (BOOL)removeLetterFromBoard:(Letter *)letter {
  NSNumber *cellKey = [NSNumber numberWithInt:letter.cellIndex];
  Letter *existingLetter = [_board objectForKey:cellKey];
  if (!existingLetter)
    return NO;
  letter.cellIndex = -1;
  [_board removeObjectForKey:cellKey];
  return YES;
}

- (NSArray *)lettersOnBoardPlacedInCurrentTurn {
  NSMutableArray *letters = [NSMutableArray arrayWithCapacity:10];
  [_board each:^(id key, Letter *letter) {
    if (letter.turnNumber == -1 && letter.playerOwner == _currentPlayerNumber)
      [letters addObject:letter];
  }];
  return [letters copy];
}

- (NSArray *)nonBombLettersOnBoardPlacedInCurrentTurn {
  NSMutableArray *letters = [NSMutableArray arrayWithCapacity:10];
  [_board each:^(id key, Letter *letter) {
    if (letter.turnNumber == -1 && letter.playerOwner == _currentPlayerNumber && ![letter isBomb])
      [letters addObject:letter];
  }];
  return [letters copy];
}

- (NSArray *)bombsPlacedInCurrentTurn {
  NSMutableArray *letters = [NSMutableArray array];
  [_board each:^(id key, Letter *letter) {
    if (letter.turnNumber == -1 && letter.playerOwner == _currentPlayerNumber && [letter isBomb])
      [letters addObject:letter];
  }];
  return [letters copy];
}

- (NSArray *)allLetters {
  return [_board allValues];
}

- (Letter *)letterAtCellIndex:(int)cellIndex {
  return [_board objectForKey:[NSNumber numberWithInt:cellIndex]];
}

- (void)removeLettersPlacedInCurrentTurn {
  [[self lettersOnBoardPlacedInCurrentTurn] enumerateObjectsUsingBlock:^(Letter *letter, NSUInteger idx, BOOL *stop) {
    [self removeLetterFromBoard:letter];
  }];
}

- (NSArray *)lettersOwnedByPlayerNumber:(int)playerNumber {
  NSMutableArray *letters = [NSMutableArray arrayWithCapacity:10];
  [_board each:^(id key, Letter *letter) {
    if (letter.playerOwner == playerNumber)
      [letters addObject:letter];
  }];
  return [letters copy];
}

- (int)ownerOfLetterAtIndex:(int)cellIndex {
  Letter *letter = [_board objectForKey:[NSNumber numberWithInt:cellIndex]];
  if (!letter)
    return -1;
  return letter.playerOwner;
}

- (Letter *)takeLetterFromBagAtRandom {
  // Bag is already shuffled so just take last element and remove it.

  NSNumber *letterValue = [_bag lastObject];

  if (!letterValue)
    return nil;

  Letter *letter = [Letter new];
  letter.letter = letterValue.integerValue;

  [_bag removeObjectAtIndex:_bag.count - 1];

  return letter;
}

- (void)putLetterBackInBag:(Letter *)letter {
  [_bag addObject:@(letter.letter)];
  _bag = [[_bag shuffledArray] mutableCopy];
}

- (int)bagTileCount {
  return _bag.count;
}

- (NSArray *)turnsByPlayerNumber:(int)playerNumber {
  NSAssert1(playerNumber == 0 || playerNumber == 1, @"invalid player number: %d", playerNumber);

  return [_turns select:^BOOL(Turn *turn) {
    return turn.playerNumber == playerNumber;
  }];
}

- (BOOL)playersHavePassedTwiceInARow {
  NSArray *turnsByFirstPlayer = [self turnsByPlayerNumber:0];
  NSArray *turnsBySecondPlayer = [self turnsByPlayerNumber:1];

  if (turnsByFirstPlayer.count >= 2 && turnsBySecondPlayer.count >= 2) {
    Turn *turnBeforeLastFirstPlayer = [turnsByFirstPlayer objectAtIndex:turnsByFirstPlayer.count - 2];
    Turn *lastTurnFirstPlayer = [turnsByFirstPlayer objectAtIndex:turnsByFirstPlayer.count - 1];

    Turn *turnBeforeLastSecondPlayer = [turnsBySecondPlayer objectAtIndex:turnsBySecondPlayer.count - 2];
    Turn *lastTurnSecondPlayer = [turnsBySecondPlayer objectAtIndex:turnsBySecondPlayer.count - 1];

    if (turnBeforeLastFirstPlayer.type == kTurnTypePass &&
        lastTurnFirstPlayer.type == kTurnTypePass &&
        turnBeforeLastSecondPlayer.type == kTurnTypePass &&
        lastTurnSecondPlayer.type == kTurnTypePass) {

      DLog(@"last two turns by both players was a pass... the match ends");
      return YES;
    }
  }

  return NO;
}

- (BOOL)emptyRackAndOutOfTiles {
  return [self sizeOfRack:[self rackForCurrentUser]] == 0 && _bag.count == 0;
}

/*

 A match ends when a player reaches their end space;
 when a player resigns the match;
 when both players pass their turns twice consecutively; or
 when no tiles remain to replenish player racks and both player racks are empty.

 */

- (BOOL)checkGameOverConditions {

#if 0 // DEBUG
  if (_state == kMatchStateActive && _turns.count >= 3) {
    DLog(@"FAKING GAME OVER STATE");

    self.state = kMatchStateEndedNormal;
    self.winningPlayer = 0;
    self.losingPlayer = 1;

    return YES;
  }
#endif

  if (_state == kMatchStateEndedDeclined) {
    DLog(@"local player declined match-challenge");

    self.losingPlayer = -1;
    self.winningPlayer = -1;

    return YES;
  }

  if (_state == kMatchStateEndedResign ||
      _state == kMatchStateEndedTimeout) {

    self.losingPlayer = _currentPlayerNumber;
    self.winningPlayer = [self opponentPlayerNumber];

    DLog(@"local player %@ resigned; opponent %@ won",
         [[self loser] usernameForDisplay],
         [[self winner] usernameForDisplay]);

    return YES;
  }

  // Check if player reached opposite corner (end cell) and has more points.
  // Player 1's end cell is in the top-right corner; player 2's in the bottom-right corner.

  int endCellIndexForCurrentPlayer = (_currentPlayerNumber == 0) ? kEndCellIndexForFirstPlayer : kEndCellIndexForSecondPlayer;

  Letter *letterAtEndCell = [self letterAtCellIndex:endCellIndexForCurrentPlayer];

  if (letterAtEndCell != nil && letterAtEndCell.playerOwner == _currentPlayerNumber) {
    self.state = kMatchStateEndedNormal;
    self.winningPlayer = _currentPlayerNumber;
    self.losingPlayer = _currentPlayerNumber == 0 ? 1 : 0;

    DLog(@"normal end (reached end cell); %@ lost; %@ win",
         [[self loser] usernameForDisplay],
         [[self winner] usernameForDisplay]);

    return YES;
  }

  if ([self emptyRackAndOutOfTiles] ||
      [self playersHavePassedTwiceInARow]) {

    self.state = kMatchStateEndedNormal;

    if (_scoreForFirstPlayer > _scoreForSecondPlayer) {
      self.winningPlayer = 0;
      self.losingPlayer = 1;
    } else if (_scoreForFirstPlayer < _scoreForSecondPlayer) {
      self.winningPlayer = 1;
      self.losingPlayer = 0;
    } else {
      self.winningPlayer = self.losingPlayer = -1;
    }

    if (_winningPlayer != -1) {
      DLog(@"normal end; %@ lost; %@ win",
           [[self loser] usernameForDisplay],
           [[self winner] usernameForDisplay]);
    } else {
      DLog(@"normal end; stalemate");
    }

    return YES;
  }

  return NO;
}

- (void)playerDidAct:(Turn *)turn {
  DLog(@"player did act");

  // Update scores

  if (_currentPlayerNumber == 0) {
    _scoreForFirstPlayer += _scoreDelta;
  } else {
    _scoreForSecondPlayer += _scoreDelta;
  }

  turn.scoreDelta = _scoreDelta;

  DLog(@"score delta: %d", _scoreDelta);

  _scoreDelta = 0;

  // Associate the turn with the match.

  [_turns addObject:turn];

  // For items placed this turn, update turn number to proper number

  int turnNumber = _turns.count;

  NSArray *addedLetters = [self lettersOnBoardPlacedInCurrentTurn];
  if (addedLetters.count > 0) {
    [addedLetters each:^(Letter *item) {
      item.turnNumber = turnNumber;
    }];
  }

  // If the match has not ended, switch current player.

  BOOL matchEnded = [self checkGameOverConditions];

  if (!matchEnded) {
    DLog(@"no game-over condition met; next player's turn");

    [self fillRackOfPlayer:_currentPlayerNumber];

    self.currentPlayerNumber = self.currentPlayerNumber == 0 ? 1 : 0;
  } else {
    turn.matchState = _state;
  }

  // If not pass-and-play, save the match, posting a local notification on success.

  __weak id weakSelf = self;

  void(^continuationBlock)() = ^{
    if (!matchEnded)
      DLog(@"bag has %d tiles remaining", _bag.count);

    if (!_passAndPlay) {
      DLog(@"posting notification of %@", kTurnDidEndNotification);

      [[NSNotificationCenter defaultCenter]
       postNotificationName:kTurnDidEndNotification
       object:nil
       userInfo:@{@"match": self, @"turn": turn}];
    }

    [[weakSelf delegate] match:weakSelf turnDidHappen:turn];
  };

  if (_passAndPlay) {
    if (matchEnded) {
      DLog(@"pass-and-play match -- match ended so deleting from local disk");
      [self removePassAndPlayMatch];
    } else {
      DLog(@"pass-and-play match -- saving match to local disk");
      [self savePassAndPlayMatch];
    }

    continuationBlock();
  } else {

    if (matchEnded && _turns.count == 1 && turn.type == kTurnTypeResign) {
      DLog(@"not saving the match object to Parse since there was only one turn: resignation ==> canceled match.");
      continuationBlock();
    } else {
      DLog(@"saving the match object to Parse");

      [_delegate matchWillSaveRemotely:self];

      [self saveMatch:^(BOOL succeeded, NSError *error) {
        [[weakSelf delegate] matchDidSaveRemotely:self success:succeeded];

        if (succeeded)
          continuationBlock();
      }];
    }
  }
}

- (NSError *)play {
  return [self playTurn];
}

// If the given player has not placed any tiles yet, then yes, the current turn will place their first word.

- (BOOL)isFirstWordForPlayerNumber:(int)playerNumber {
  return [_board select:^BOOL(NSNumber *cellIndex, Letter *letter) {
    return letter.playerOwner == playerNumber && letter.turnNumber != -1;
  }].count == 0;
}

- (NSError *)playTurn {
  if (!_passAndPlay)
    NSAssert([self currentUserPlayerNumber] == _currentPlayerNumber, @"not your turn");

  NSArray *addedLetters = [self lettersOnBoardPlacedInCurrentTurn];

  // Only letters or only bombs may be placed in one turn.
  // Thus, if we have only bombs, blow them up!

  if ([addedLetters select:^BOOL(id obj) { return [obj isBomb]; }].count == addedLetters.count) {
    if (_board.count - [self lettersOnBoardPlacedInCurrentTurn].count == 0) {
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"There are no letters to blow up yet ... patience, grasshopper.", nil) };
      return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNoLettersToBlowUp userInfo:userInfo];
    }

    DLog(@"KaBOOM!");

    NSArray *bombIndices = [addedLetters map:^id(id obj) {
      return @([obj cellIndex]);
    }];

    [addedLetters each:^(Letter *letter) {
      [self detonateBombAtCellIndex:letter.cellIndex];
    }];

    DLog(@"bombs at: %@", bombIndices);

    Turn *turn = [Turn new];
    turn.playerNumber = _currentPlayerNumber;
    turn.type = kTurnTypeBomb;
    turn.matchState = _state;
    turn.bombsDetonatedAtCellIndices = bombIndices;
    [self playerDidAct:turn];

    return nil;
  }

  if (addedLetters.count == 0 || (addedLetters.count <= 1 && _turns.count < 2)) {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Drag some letters from the rack to the board and try again.", nil) };
    return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNothingPlayed userInfo:userInfo];
  }

  BOOL isFirstWord = [self isFirstWordForPlayerNumber:_currentPlayerNumber];

  DLog(@"first word %@", isFirstWord ? @"YES" : @"NO");

  // On first turn of match, the word placed must start on the player's start cell...

  if (isFirstWord && _currentPlayerNumber == 0) {
    if ([addedLetters select:^BOOL(Letter *letter) { return letter.cellIndex == kStartCellIndexForFirstPlayer; }].count == 0) {
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Start by forming a word from your start space (the green one in the top-left corner)", nil) };
      return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeFirstNotOnStart userInfo:userInfo];
    }
  } else if (isFirstWord && _currentPlayerNumber == 1) {
    if ([addedLetters select:^BOOL(Letter *letter) { return letter.cellIndex == kStartCellIndexForSecondPlayer; }].count == 0) {
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Start by forming a word from your start space (the orange one in the bottom-left corner)", nil) };
      return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeFirstNotOnStart userInfo:userInfo];
    }
  }

  // Tiles placed must be on the same diagonal (either direction NW-SE or SW-NE).

  if (![self onSameDiagonal:addedLetters]) {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Place letters on the same diagonal.", nil) };
    return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNothingPlayed userInfo:userInfo];
  }

  if ([self containsEmptySpacesOnDiagonal:addedLetters]) {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Place letters such that there are no empty spaces between them.", nil) };
    return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNoBlanks userInfo:userInfo];
  }

  NSMutableSet *validWords = [NSMutableSet set];    // Word*
  NSMutableSet *invalidWords = [NSMutableSet set];  // NSString*
  NSMutableSet *allWords = [NSMutableSet set];      // Word*

  [self validate:addedLetters all:allWords valid:validWords invalid:invalidWords];
  DLog(@"valid words: %d, invalid words: %d", validWords.count, invalidWords.count);

  if (validWords.count == 0 && invalidWords.count == 0) {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"No valid words were formed.", nil) };
    return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNothingPlayed userInfo:userInfo];
  }

  // Check that the words formed are built off of existing words (owned by same player [checked earlier]).
  // NB: first turns for each player aren't built off existing words

  if (!isFirstWord) {
    BOOL somePlacedWordHasAnExistingLetter = NO;

    for (Word *word in allWords) {
      for (Letter *letter in word.letters) {
        if (letter.turnNumber != -1) {
          somePlacedWordHasAnExistingLetter = YES;
          break;
        }
      }
    }

    if (!somePlacedWordHasAnExistingLetter) {
      DLog(@"No word formed was built off an existing word...");
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid letter placement. Place letters to form words using at least one letter from your existing words.", nil) };
      return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeNothingPlayed userInfo:userInfo];
    }
  }

  if (invalidWords.count > 0) {
    DLog(@"encountered some invalid words: %@", invalidWords);
    NSString *singular = NSLocalizedString(@"%@ is an invalid word.", @"singular version; %@ is the word");
    NSString *plural = NSLocalizedString(@"%@ are invalid words.", @"plural version; %@ is a comma-separated list of words");
    NSString *fmt = (invalidWords.count == 1) ? singular : plural;
    NSString *wordsAsString = [[invalidWords allObjects] componentsJoinedByString:@", "];
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:fmt, wordsAsString], @"invalidWords": invalidWords };
    return [NSError errorWithDomain:kMatchErrorDomain code:kMatchErrorCodeInvalidWords userInfo:userInfo];
  }

  // Score the words formed.

  [validWords enumerateObjectsUsingBlock:^(Word *word, BOOL *stop) {
    NSMutableString *str = [NSMutableString string];

    for (Letter *letter in word.letters)
      [str appendFormat:@"'%c'@(%d,%d) ", [letter effectiveLetter], cellX(letter.cellIndex), cellY(letter.cellIndex)];

    DLog(@"scoring word '%@' %@", [word string], str);

    int scoreForWord = [word score];

    DLog(@"score for word '%@' = %d", [word string], scoreForWord);

    _scoreDelta += scoreForWord;
  }];

  // Player gets a bonus for using all letters in a full rack.

  if (addedLetters.count == kRackTileCount) {
    DLog(@"bingo bonus");
    _scoreDelta += kBingoBonusPoints;
  }

  // Record the turn

  if (_turns.count == 1 && _state == kMatchStatePending)
    self.state = kMatchStateActive;  // Accepted the challenge.

  Turn *turn = [Turn new];
  turn.playerNumber = _currentPlayerNumber;
  turn.type = kTurnTypePlay;
  turn.matchState = _state;
  turn.wordsFormed = [validWords allObjects];
  [self playerDidAct:turn];

  return nil;
}

- (CGPoint)diagonalNWForLetter:(Letter *)letter {
  int x = cellX(letter.cellIndex);
  int y = cellY(letter.cellIndex);

  while (isValidCell(x,y))
    --x, --y;

  return CGPointMake(x,y);
}

- (CGPoint)diagonalSWForLetter:(Letter *)letter {
  int x = cellX(letter.cellIndex);
  int y = cellY(letter.cellIndex);

  while (isValidCell(x,y))
    --x, ++y;

  return CGPointMake(x, y);
}

- (BOOL)onSameDiagonal:(NSArray *)letters {
  // Find extreme point in NW and SW for each letter and add each to a set.
  // One or the other set should only have exactly 1 member.

  NSMutableSet *nw = [NSMutableSet setWithCapacity:letters.count];
  NSMutableSet *sw = [NSMutableSet setWithCapacity:letters.count];

  for (Letter *letter in letters) {
    [nw addObject:[NSValue valueWithCGPoint:[self diagonalNWForLetter:letter]]];
    [sw addObject:[NSValue valueWithCGPoint:[self diagonalSWForLetter:letter]]];
  }

  return nw.count == 1 || sw.count == 1;
}

// Precond: already know that all the letters are on the same diagonal.

- (BOOL)containsEmptySpacesOnDiagonal:(NSArray *)placedLetters {
  // Find extreme NW and SW board cells to determine diagonal.

  NSMutableSet *nw = [NSMutableSet setWithCapacity:placedLetters.count];
  NSMutableSet *sw = [NSMutableSet setWithCapacity:placedLetters.count];

  for (Letter *letter in placedLetters) {
    [nw addObject:[NSValue valueWithCGPoint:[self diagonalNWForLetter:letter]]];
    [sw addObject:[NSValue valueWithCGPoint:[self diagonalSWForLetter:letter]]];
  }

  NSAssert(nw.count == 1 || sw.count == 1, @"invalid placement");

  NSMutableSet *set = nw;
  int dx = 1;
  int dy = 1;

  if (sw.count == 1) {
    set = sw;
    dy = -1;
  }

  // Walk diagonal from (sx,sy) following (dx,dy).
  // Note first cell in (sx,sy) that has a letter we own.
  // Note the last cell in (ex,ey) that has a letter we own.
  // Walk diagonal from (sx,sy) to (ex,ey) and check that there are no empty cells.

  int sx, sy, ex, ey;

  CGPoint startPoint = [[set anyObject] CGPointValue];
  int x = startPoint.x, y = startPoint.y;
  while (isValidCell(x+dx, y+dy)) {
    x += dx, y += dy;
    Letter *aLetter = [self letterAtCellIndex:cellIndexFor(x, y)];
    if (aLetter && aLetter.playerOwner == _currentPlayerNumber && aLetter.turnNumber == -1) {
      sx = x, sy = y;
      break;
    }
  }

  ex = x = sx, ey = y = sy;
  while (isValidCell(x+dx, y+dy)) {
    x += dx, y += dy;
    Letter *aLetter = [self letterAtCellIndex:cellIndexFor(x, y)];
    if (aLetter && aLetter.playerOwner == _currentPlayerNumber && aLetter.turnNumber == -1) {
      ex = x, ey = y;
      // no break here
    }
  }

  x = sx, y = sy;
  while (x != ex && y != ey) {
    x += dx, y += dy;
    Letter *aLetter = [self letterAtCellIndex:cellIndexFor(x, y)];
    if (!aLetter)
      return YES;
  }

  return NO;
}

- (BOOL)isCellOccupied:(int)index {
  return [_board objectForKey:[NSNumber numberWithInt:index]] != nil;
}

- (BOOL)isEmptyCellX:(int)x y:(int)y {
  return [self letterAtCellIndex:cellIndexFor(x, y)] == nil;
}

// Walk in given direction until we hit the a board boundary, an empty cell, or a cell containing an opponent's letter.

- (CGPoint)furthestLetterFrom:(Letter *)aLetter direction:(int)direction {
  // Walk in the given direction until we hit a boundary, noting the cell at which we last saw one of our letters

  int xi=0, yi=0;
  switch (direction) {
    case kBoardDirectionSW: xi = -1, yi = +1; break;
    case kBoardDirectionNW: xi = -1, yi = -1; break;
    case kBoardDirectionNE: xi = +1, yi = -1; break;
    case kBoardDirectionSE: xi = +1, yi = +1; break;
  }

  int x = cellX(aLetter.cellIndex);
  int y = cellY(aLetter.cellIndex);

  int lastXWithLetter = x;
  int lastYWithLetter = y;

  while (isValidCell(x+xi, y+yi) && ![self isEmptyCellX:x+xi y:y+yi]) {
    x += xi, y += yi;

    Letter *aLetter = [self letterAtCellIndex:cellIndexFor(x, y)];

#if ALLOW_OPPONENTS_LETTERS

    // Players are allowed to use their opponent's letters already placed on the
    // board in a previous turn to form their own letters.

    if (aLetter) {
      lastXWithLetter = x;
      lastYWithLetter = y;
    }

#else

    // Players are disallowed from using their opponent's letters already placed on the
    // board in a previous turn to form their own letters.

    if (aLetter) {
      if (aLetter.playerOwner == _currentPlayerNumber) {
        lastXWithLetter = x;
        lastYWithLetter = y;
      } else {
        break;
      }
    }

#endif
  }

  return CGPointMake(lastXWithLetter, lastYWithLetter);
}

- (Word *)extractWordBetween:(CGPoint)startCell and:(CGPoint)endCell {  // inclusive
  Word *word = [Word new];

  if (startCell.x == endCell.x && startCell.y == endCell.y) {
    Letter *letter = [self letterAtCellIndex:cellIndexFor(endCell.x, endCell.y)];
    if (!letter) return nil;
    [word addLetter:letter];
    return word;
  }

  int xi = endCell.x > startCell.x ? 1 : -1;
  int yi = endCell.y > startCell.y ? 1 : -1;

  for (int x = startCell.x, y = startCell.y; x != endCell.x && y != endCell.y; x += xi, y += yi) {
    Letter *letter = [self letterAtCellIndex:cellIndexFor(x, y)];
    if (!letter) return nil;
    [word addLetter:letter];
  }

  if (endCell.x != startCell.x && endCell.y != startCell.y) {
    Letter *letter = [self letterAtCellIndex:cellIndexFor(endCell.x, endCell.y)];
    if (!letter) return nil;
    [word addLetter:letter];
  }

  return word;
}

- (void)validate:(NSArray *)letters
             all:(NSMutableSet *)allWords
           valid:(NSMutableSet *)validWords
         invalid:(NSMutableSet *)invalidWords {

  NSMutableSet *words = [NSMutableSet set];

  [letters enumerateObjectsUsingBlock:^(Letter *letter, NSUInteger idx, BOOL *stop) {
    Word *horizWord = [self extractWordBetween:[self furthestLetterFrom:letter direction:kBoardDirectionSW]
                                           and:[self furthestLetterFrom:letter direction:kBoardDirectionNE]];

    Word *verticalWord = [self extractWordBetween:[self furthestLetterFrom:letter direction:kBoardDirectionNW]
                                              and:[self furthestLetterFrom:letter direction:kBoardDirectionSE]];

    if (horizWord.length > 1) {
      DLog(@"from letter %c hword=%@", [letter effectiveLetter], [horizWord string]);
      [words addObject:horizWord];
    }

    if (verticalWord.length > 1) {
      DLog(@"from letter %c vword=%@", [letter effectiveLetter], [verticalWord string]);
      [words addObject:verticalWord];
    }
  }];

  for (Word *w in words)
    DLog(@"word formed from placed letters: %@", [w string]);

  [allWords addObjectsFromArray:[words allObjects]];

  [self lookupWords:[words allObjects]
         validWords:validWords
       invalidWords:invalidWords];
}

// Note: validWords will contain Word objects; invalidWords will contain NSString objects.

- (void)lookupWords:(NSArray *)words
         validWords:(NSMutableSet *)validWords
       invalidWords:(NSMutableSet *)invalidWords {
  
  WordList *wordList = [WordList sharedWordList];

  [words enumerateObjectsUsingBlock:^(Word *word, NSUInteger idx, BOOL *stop) {
    NSMutableString *str = [NSMutableString string];

    for (Letter *letter in word.letters) {
      [str appendFormat:@"%c@(%d,%d) ",
       [letter effectiveLetter],
       cellX(letter.cellIndex),
       cellY(letter.cellIndex)];
    }

    DLog(@"looking up '%@' %@", [word string], str);

    if ([wordList contains:word]) {
      DLog(@"... '%@' is valid", [word string]);
      [validWords addObject:word];
    } else {
      DLog(@"... '%@' is invalid", [word string]);
      [invalidWords addObject:[word string]];
    }
  }];
}

- (void)pass {
  if (!_passAndPlay) {
    NSAssert([self currentUserPlayerNumber] == _currentPlayerNumber, @"not your turn");
  }

  [self recallLettersPlacedInCurrentTurnIncludingBombs:YES];

  Turn *turn = [Turn new];
  turn.playerNumber = _currentPlayerNumber;
  turn.type = kTurnTypePass;
  turn.matchState = _state;
  [self playerDidAct:turn];
}

- (void)resign {
  self.state = kMatchStateEndedResign;

  [self recallLettersPlacedInCurrentTurnIncludingBombs:YES];

  Turn *turn = [Turn new];
  turn.playerNumber = _currentPlayerNumber;
  turn.type = kTurnTypeResign;
  turn.matchState = kMatchStateEndedResign;
  [self playerDidAct:turn];
}

- (void)decline {
  self.state = kMatchStateEndedDeclined;

  Turn *turn = [Turn new];
  turn.playerNumber = _currentPlayerNumber;
  turn.type = kTurnTypeDecline;
  turn.matchState = kMatchStateEndedDeclined;
  [self playerDidAct:turn];
}

- (BOOL)canMoveLetter:(Letter *)letter {
  // It's not your turn!

  if (!_passAndPlay && [self currentUserPlayerNumber] != _currentPlayerNumber)
    return NO;

  // Cannot move letters placed in an earlier turn.

  if (letter.turnNumber != -1)
    return NO;

  // You can only move your own letters

  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  if (letter.playerOwner != playerNumber)
    return NO;

  return YES;
}

- (BOOL)canMoveLetterToRack:(Letter *)letter {
  if (![self canMoveLetter:letter])
    return NO;

  return [self sizeOfRack:[self rackForCurrentUser]] < kRackTileCount;
}

- (BOOL)moveLetter:(Letter *)letter toBoardAtCellIndex:(int)cellIndex {
  NSAssert1(cellIndex >= 0 && cellIndex < kBoardCellCount, @"invalid cell index: %d", cellIndex);

  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];

  if (letter.playerOwner != playerNumber) {
    DLog(@"Not your letter to move!");
    return NO;
  }

  if (letter.turnNumber != -1 && letter.rackIndex != -1) {
    DLog(@"Letters may only be moved if the player placed them in the current turn; turn=%d", letter.turnNumber);
    return NO;
  }

  Letter* existingletter = [self letterAtCellIndex:cellIndex];

  if (existingletter && existingletter != letter) {
    DLog(@"Cannot move a letter to where there is already a letter");
    return NO;
  }

  DLog(@"%@  <%@> to board at cell %d", NSStringFromSelector(_cmd), letter, cellIndex);

  BOOL wasAlreadyOnBoard = (letter.cellIndex != -1);

  if (letter.rackIndex != -1) {
    DLog(@"move from rack to board");

    NSMutableArray *rack = playerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;
    [self removeLetterAtIndex:letter.rackIndex rack:rack];

  } else if (wasAlreadyOnBoard) {
    DLog(@"move within the board");
  }

  [self removeLetterFromBoard:letter];

  letter.cellIndex = cellIndex;
  letter.rackIndex = -1;
  letter.turnNumber = -1;

  [self addLetterToBoard:letter];

  return YES;
}

- (BOOL)moveLetter:(Letter *)letter toRackAtIndex:(int)targetRackIndex {
  NSParameterAssert(targetRackIndex >= 0 && targetRackIndex < kRackTileCount);

  if (letter.turnNumber != -1) {
    DLog(@"cannot move to rack -- not placed this turn (turn=%d)", letter.turnNumber);
    return NO;
  }

  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  if (letter.playerOwner != playerNumber) {
    DLog(@"cannot move to rack -- not owned by local user");
    return NO;
  }

  NSMutableArray *rack = playerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;

  DLog(@"before %@ rack = %@", NSStringFromSelector(_cmd), [self rackAsString:rack]);

  BOOL wasAlreadyInRack = (letter.rackIndex != -1);

  if (letter.cellIndex != -1) {
    DLog(@"%@ move from board back to rack", NSStringFromSelector(_cmd));
    [self removeLetterFromBoard:letter];
  }

  letter.cellIndex = -1;

  id existingItem = [rack objectAtIndex:targetRackIndex];

  if (wasAlreadyInRack) {
    DLog(@"reorder by swapping letters within the rack");

    [rack exchangeObjectAtIndex:letter.rackIndex withObjectAtIndex:targetRackIndex];

    if (existingItem != [NSNull null])
      [existingItem setRackIndex:letter.rackIndex];

    letter.rackIndex = targetRackIndex;
  } else {
    letter.rackIndex = targetRackIndex;
    [self addLetter:letter toRack:rack];
  }

  letter.substituteLetter = 0;

  DLog(@"after %@ rack = %@", NSStringFromSelector(_cmd), [self rackAsString:rack]);

  return YES;
}

#pragma mark - rack

- (NSArray *)rackForCurrentUser {
  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  return playerNumber == 0 ? [_rackForFirstPlayer copy] : [_rackForSecondPlayer copy];
}

// The bits about NSNull exist so that we don't slide tiles needlessly in a rack
// when the user drags a tile out from the rack to the board.  We just put a placeholder
// value (NSNull) in its now vacant slot.

- (void)fillRackOfPlayer:(int)playerNumber {
  DLog(@"begin %@:%d", NSStringFromSelector(_cmd), playerNumber);

  NSMutableArray *rack = playerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;

  while (YES) {
    Letter *letter = [self takeLetterFromBagAtRandom];

    if (!letter)
      break;

    letter.playerOwner = playerNumber;
    letter.turnNumber = -1;

    if (![self addLetter:letter toRack:rack]) {
      [self putLetterBackInBag:letter];
      break;
    }
  }

  DLog(@"after %@ player=%d rack=%@", NSStringFromSelector(_cmd), playerNumber, [self rackAsString:rack]);
}

- (BOOL)addLetter:(Letter *)letter toRack:(NSMutableArray *)rack {
  letter.substituteLetter = 0;

  // preferred seating?

  if (letter.rackIndex >= 0 &&
      letter.rackIndex < rack.count &&
      [rack objectAtIndex:letter.rackIndex] == [NSNull null]) {

    [rack replaceObjectAtIndex:letter.rackIndex withObject:letter];
    return YES;
  }

  // No empty spots since not already full of letters or placeholders (NSNull)?

  if (rack.count < kRackTileCount) {
    letter.cellIndex = -1;
    letter.rackIndex = rack.count;

    [rack addObject:letter];
    return YES;
  }

  // Find an "empty" slot.

  int index = 0;

  for (id entry in rack) {
    if (entry == [NSNull null]) {
      [rack replaceObjectAtIndex:index withObject:letter];

      letter.cellIndex = -1;
      letter.rackIndex = index;

      return YES;
    }

    ++index;
  }

  // No vacancy.

  return NO;
}

- (void)removeLetterAtIndex:(int)index rack:(NSMutableArray *)rack {
  NSAssert1(index >= 0 && index < kRackTileCount, @"invalid rack index: %d", index);

  id item = [rack objectAtIndex:index];
  if ([item isKindOfClass:[Letter class]])
    [item setRackIndex:-1];

  [rack replaceObjectAtIndex:index withObject:[NSNull null]];

  DLog(@"after %@ rack = %@", NSStringFromSelector(_cmd), [self rackAsString:rack]);
}

- (int)sizeOfRack:(NSArray *)rack {
  int n = 0;

  for (id entry in rack)
    if (entry != [NSNull null])
      ++n;

  return n;
}

- (void)recallLettersPlacedInCurrentTurnIncludingBombs:(BOOL)includingBombs {
  if (!_passAndPlay) {
    NSAssert([self currentUserPlayerNumber] == _currentPlayerNumber, @"not your turn");
  }

  NSMutableArray *rack = _currentPlayerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;

  [[self lettersOnBoardPlacedInCurrentTurn] enumerateObjectsUsingBlock:^(Letter *letter, NSUInteger idx, BOOL *stop) {
    if (!includingBombs && [letter isBomb])
      return;
    [self removeLetterFromBoard:letter];
    [self addLetter:letter toRack:rack];
    letter.turnNumber = -1;
  }];
}

- (void)recallBombsPlacedInCurrentTurn {
  if (!_passAndPlay) {
    NSAssert([self currentUserPlayerNumber] == _currentPlayerNumber, @"not your turn");
  }

  NSMutableArray *rack = _currentPlayerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;

  [[self lettersOnBoardPlacedInCurrentTurn] enumerateObjectsUsingBlock:^(Letter *letter, NSUInteger idx, BOOL *stop) {
    if (![letter isBomb])
      return;
    [self removeLetterFromBoard:letter];
    [self addLetter:letter toRack:rack];
    letter.turnNumber = -1;
  }];
}

- (NSString *)rackAsString:(NSArray *)rack {
  NSMutableString *str = [NSMutableString stringWithString:@"< "];

  for (id item in rack) {
    if (item == [NSNull null]) {
      [str appendString:@"- "];
    } else {
      int letter = [item letter];

      if (letter == ' ')
        [str appendString:@"* "];
      else
        [str appendFormat:@"%c ", letter];
    }
  }

  [str appendString:@">"];

  return str;
}

- (NSString *)mostRecentTurnDescription {
  if (_turns.count == 0)
    return nil;

  NSString *opponentName = [self currentUserPlayerNumber] == 0 ? [_secondPlayer usernameForDisplay] : [_firstPlayer usernameForDisplay];

  Turn *turn = [_turns lastObject];

  if (turn.matchState == kMatchStateEndedNormal) {
    if (_winningPlayer == -1 && _losingPlayer == -1) {
      return [NSString stringWithFormat:@"You tied vs %@ (%d - %d)", opponentName, _scoreForFirstPlayer, _scoreForFirstPlayer];
    }

    if (_winningPlayer == [self currentUserPlayerNumber]) {
      int winnerScore = _winningPlayer == 0 ? _scoreForFirstPlayer : _scoreForSecondPlayer;
      int loserScore = _losingPlayer == 0 ? _scoreForFirstPlayer : _scoreForSecondPlayer;
      return [NSString stringWithFormat:@"You won vs %@ (%d - %d)!", opponentName, winnerScore, loserScore];
    }

    if (_losingPlayer == [self currentUserPlayerNumber]) {
      int winnerScore = _winningPlayer == 0 ? _scoreForFirstPlayer : _scoreForSecondPlayer;
      int loserScore = _losingPlayer == 0 ? _scoreForFirstPlayer : _scoreForSecondPlayer;
      return [NSString stringWithFormat:@"%@ won (%d - %d)", opponentName, winnerScore, loserScore];
    }
  }

  switch (turn.type) {
    case kTurnTypeDecline:
      return nil;

    case kTurnTypePass:
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"%@ passed", nil), opponentName];
      return [NSString stringWithFormat:NSLocalizedString(@"You passed vs %@", nil), opponentName];

    case kTurnTypePlay: {
      NSString *words = [[turn.wordsFormed map:^id(id obj) {
        if ([obj isKindOfClass:Word.class])
          return [[obj string] uppercaseString];
        return obj;
      }] componentsJoinedByString:@", "];
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"%@ played %@ for %d points", nil), opponentName, words, turn.scoreDelta];
      return [NSString stringWithFormat:NSLocalizedString(@"You played %@ for %d points vs %@", nil), words, turn.scoreDelta, opponentName];
    }

    case kTurnTypeResign:
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"You resigned vs %@", nil), opponentName];
      return [NSString stringWithFormat:NSLocalizedString(@"%@ resigned", nil), opponentName];

    case kTurnTypeTimeout:
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"%@ forfeited for not playing", nil), opponentName];
      return [NSString stringWithFormat:NSLocalizedString(@"You forfeited for not playing vs %@", nil), opponentName];

    case kTurnTypeExchange:
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"%@ exchanged tiles", nil), opponentName];
      return [NSString stringWithFormat:NSLocalizedString(@"You exchanged tiles vs %@", nil), opponentName];

    case kTurnTypeBomb: {
      int bombCount = turn.bombsDetonatedAtCellIndices.count;
      
      if ([self currentUserPlayerNumber] == _currentPlayerNumber)
        return [NSString stringWithFormat:NSLocalizedString(@"%@ detonated %@ bomb%@!", nil),
                opponentName,
                bombCount == 1 ? @"a" : [NSString stringWithFormat:@"%d", bombCount],
                bombCount == 1 ? @"" : @"s"];

      return [NSString stringWithFormat:NSLocalizedString(@"You detonated %@ bomb%@ vs %@", nil),
              opponentName,
              bombCount == 1 ? @"a" : [NSString stringWithFormat:@"%d", bombCount],
              bombCount == 1 ? @"" : @"s"];
    }
  }

  return nil;
}

// As per standard Scrabble rules.

- (BOOL)canExchangeLettersInRack {
  return _bag.count >= kRackTileCount;
}

- (void)exchangeRackLettersAtIndexes:(NSArray *)indexes {
  if (!_passAndPlay) {
    NSAssert([self currentUserPlayerNumber] == _currentPlayerNumber, @"not your turn");
  }

  if (![self canExchangeLettersInRack]) {
    DLog(@"cannot exchange letters in rack");
    return;
  }

  DLog(@"exchanging letters in rack at indexes: %@", indexes);

  [self recallLettersPlacedInCurrentTurnIncludingBombs:YES];

  NSMutableArray *rack = _currentPlayerNumber == 0 ? _rackForFirstPlayer : _rackForSecondPlayer;

  // Remove selected tiles from rack and put aside.

  NSArray *itemsToExchange = [indexes map:^id(id obj) {
    int index = [obj intValue];
    Letter *existingRackItem = [rack objectAtIndex:index];
    [self removeLetterAtIndex:index rack:rack];
    return existingRackItem;
  }];

  // Pick new tiles from the bag and add to the rack

  for (int i=0; i<indexes.count; ++i) {
    Letter *letter = [self takeLetterFromBagAtRandom];
    letter.playerOwner = _currentPlayerNumber;
    [self addLetter:letter toRack:rack];
  }

  // Put the removed tiles back in the bag

  [itemsToExchange each:^(Letter *letter) {
    [self putLetterBackInBag:letter];
  }];

  // This counts as taking a turn.

  Turn *turn = [Turn new];
  turn.playerNumber = _currentPlayerNumber;
  turn.type = kTurnTypeExchange;
  turn.matchState = _state;  // That is, no change
  [self playerDidAct:turn];
}

- (void)shuffleRack {
  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  NSArray *sourceArray = (playerNumber == 0) ? _rackForFirstPlayer : _rackForSecondPlayer;

  NSArray *shuffledArray = [sourceArray shuffledArray];

  // Put any blanks at the end but leave the rest shuffled.

  NSArray *sortedArray = [shuffledArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    if (obj1 == [NSNull null] || [obj1 isBomb] || [obj1 isBlank])
      return NSOrderedDescending;

    if (obj2 == [NSNull null] || [obj1 isBomb] || [obj1 isBlank])
      return NSOrderedAscending;

    return NSOrderedSame;
  }];

  [sortedArray enumerateObjectsUsingBlock:^(id letter, NSUInteger idx, BOOL *stop) {
    if (letter != [NSNull null]) {
      [letter setRackIndex:idx];
      [letter setTurnNumber:-1];
    }
  }];

  DLog(@"shuffledArray=%@", sortedArray);

  if (playerNumber == 0)
    _rackForFirstPlayer = [sortedArray mutableCopy];
  else
    _rackForSecondPlayer = [sortedArray mutableCopy];
}

#pragma mark - player queries

- (int)currentUserPlayerNumber {
  // There is no relevant "current user" for pass-and-play matches.

  if (_passAndPlay)
    return _currentPlayerNumber;

  if (_state == kMatchStatePending && _turns.count == 0)
    return 0;

  NSString *currentUserObjectId = [PFUser currentUser].objectId;

  if ([currentUserObjectId isEqualToString:_firstPlayer.objectId])
    return 0;

  if ([currentUserObjectId isEqualToString:_secondPlayer.objectId])
    return 1;

  DLog(@"current user is not a participant in this match!");

  return -1;
}

- (int)opponentPlayerNumber {
  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  return playerNumber == 0 ? 1 : 0;
}

- (PFUser *)currentUserPlayer {
  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  return playerNumber == 0 ? _firstPlayer : _secondPlayer;
}

- (PFUser *)opponentPlayer {
  int playerNumber = (_passAndPlay) ? _currentPlayerNumber : [self currentUserPlayerNumber];
  return playerNumber == 0 ? _secondPlayer : _firstPlayer;
}

- (PFUser *)playerForPlayerNumber:(int)playerNumber {
  return playerNumber == 0 ? _firstPlayer : _secondPlayer;
}

- (PFUser *)currentPlayer {
  return _currentPlayerNumber == 0 ? _firstPlayer : _secondPlayer;
}

- (BOOL)currentUserIsCurrentPlayer {
  return [self currentUserPlayerNumber] == _currentPlayerNumber;
}

- (PFUser *)winner {
  if (_winningPlayer == -1)
    return nil;

  if (_winningPlayer == 0)
    return _firstPlayer;

  return _secondPlayer;
}

- (PFUser *)loser {
  if (_losingPlayer == -1)
    return nil;

  if (_losingPlayer == 0)
    return _firstPlayer;

  return _secondPlayer;
}

#pragma mark - misc

- (NSString *)matchID {
  return _match.objectId;
}

- (NSString *)updatedAtInWords {
  if (_passAndPlay)
    return nil;
  
  return [_match.updatedAt timeAgoInWords];
}

#pragma mark - bombs

- (void)detonateBombAtCellIndex:(int)cellIndex {
  DLog(@"detonate bomb at cell %d, %d", cellX(cellIndex), cellY(cellIndex));

  Letter *bombLetter = [_board objectForKey:@(cellIndex)];

  if (![bombLetter isBomb]) {
    DLog(@"cannot detonate -- not a bomb!");
    return;
  }

  [self removeLetterFromBoard:bombLetter]; // it blows itself up / single-use.

  NSMutableArray *indicesBlownUp = [NSMutableArray arrayWithCapacity:10];

  float blastRadiusSquared = kBombBlastRadius * kBombBlastRadius;

  int blastX = cellX(cellIndex);
  int blastY = cellY(cellIndex);

  for (int y = 0; y < kBoardSize; ++y) {
    for (int x = 0; x < kBoardSize; ++x) {
      
      if (!isValidCell(x, y))
        continue;

      Letter *letter = [self letterAtCellIndex:cellIndexFor(x, y)];

#if BLOW_UP_OWN_LETTERS

      if (!letter)
        continue;

#else

      if (!letter || letter.playerOwner == _currentPlayerNumber)
        continue;

#endif

      float distanceSquared = (blastX - x) * (blastX - x) + (blastY - y) * (blastY - y);
      if (distanceSquared <= blastRadiusSquared) {  // avoid sqrtf call -- no need.
        DLog(@"cell at %d, %d in blast radius -- bye!", x, y);
        [indicesBlownUp addObject:@(letter.cellIndex)];
        [self removeLetterFromBoard:letter];
      }
    }
  }

  [_delegate match:self didBlowUpLettersAtIndices:[indicesBlownUp copy] withBombAtCellIndex:cellIndex];
}

@end
