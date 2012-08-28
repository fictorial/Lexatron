@class Match;
@class Turn;
@class Letter;

@protocol MatchDelegate <NSObject>
- (void)match:(Match *)match turnDidHappen:(Turn *)turn;
- (void)matchDidSaveRemotely:(Match *)match success:(BOOL)success;
- (void)matchWillSaveRemotely:(Match *)match;
@end

enum {
  kMatchErrorCodeFirstNotOnStart = 1000,   // first word placed must start on specific cell
  kMatchErrorCodeLettersSpansRowsColumns,  // words formed must be in a single row or single column
  kMatchErrorCodeNoBlanks,                 // words formed must be on contiguous tiles
  kMatchErrorCodeInvalidWords,             // not in dictionary; userInfo is array of invalid words
  kMatchErrorCodeNothingPlayed,            // nothing was placed!
  kMatchErrorCodeTooShort                  // word formed is too short.
};

extern NSString * const kMatchErrorDomain;

typedef void (^DecodeMatchCompletionBlock)(Match *match, NSError *error);

@interface Match : NSObject

@property (nonatomic, readonly) int state;

@property (nonatomic, weak) id<MatchDelegate> delegate;

@property (nonatomic, readonly, strong) PFUser *firstPlayer;
@property (nonatomic, readonly, strong) PFUser *secondPlayer;

@property (nonatomic, readonly) int currentPlayerNumber;    // {0,1}

@property (nonatomic, readonly, assign) int winningPlayer;  // {-1, 0, 1}
@property (nonatomic, readonly, assign) int losingPlayer;   // {-1, 0, 1}

@property (nonatomic, readonly) int scoreForFirstPlayer;    // ≥ 0
@property (nonatomic, readonly) int scoreForSecondPlayer;   // ≥ 0

@property (nonatomic, readonly, copy) NSDictionary *board;  // NSNumber (cell index) => Letter*

@property (nonatomic, readonly, copy) NSArray *rackForFirstPlayer;  // NSArray of (Letter* or NSNull)
@property (nonatomic, readonly, copy) NSArray *rackForSecondPlayer;

@property (nonatomic, readonly, copy) NSArray *turns;       // Turn objects

@property (nonatomic, assign) BOOL passAndPlay;

- (id)initWithPlayer:(PFUser *)firstPlayer player:(PFUser *)secondPlayer;
+ (id)matchWithExistingMatchObject:(PFObject *)match block:(DecodeMatchCompletionBlock)block;
+ (id)matchWithRandomOpponentCompletion:(PFBooleanResultBlock)block;
+ (id)resumablePassAndPlayMatch;

- (BOOL)addLetterToBoard:(Letter *)letter;
- (BOOL)removeLetterFromBoard:(Letter *)letter;

- (BOOL)isCellOccupied:(int)index;
- (NSArray *)lettersOnBoardPlacedInCurrentTurn;
- (NSArray *)allLetters;
- (void)removeLettersPlacedInCurrentTurn;
- (NSArray *)lettersOwnedByPlayerNumber:(int)playerNumber;  // NSArray of Letter*
- (int)ownerOfLetterAtIndex:(int)cellIndex;  // {-1,0,1}
- (Letter *)letterAtCellIndex:(int)cellIndex;

- (BOOL)canMoveLetter:(Letter *)item;
- (BOOL)canMoveLetterToRack:(Letter *)item;
- (BOOL)moveLetter:(Letter *)letter toBoardAtCellIndex:(int)cellIndex;
- (BOOL)moveLetter:(Letter *)letter toRackAtIndex:(int)targetRackIndex;

- (NSError *)play;
- (void)pass;
- (void)resign;
- (void)decline;
- (void)recallLettersPlacedInCurrentTurn;
- (void)shuffleRack;

- (BOOL)canExchangeLettersInRack;
- (void)exchangeRackLettersAtIndexes:(NSArray *)indexes;  // Really, this a turn action

- (NSArray *)rackForCurrentUser;  // array of Letter*; nil if not in the match
- (NSString *)rackAsString:(NSArray *)rack;

- (int)bagTileCount;

- (int)currentUserPlayerNumber;
- (PFUser *)currentUserPlayer;
- (int)opponentPlayerNumber;
- (PFUser *)opponentPlayer;
- (PFUser *)playerForPlayerNumber:(int)playerNumber;
- (BOOL)currentUserIsCurrentPlayer;

- (PFUser *)winner;
- (PFUser *)loser;

- (NSString *)matchID;

- (NSString *)mostRecentTurnDescription;
- (NSString *)updatedAtInWords;

@end