enum {
  kTurnTypePlay,             // player placed letters, attacks, defenses successfully
  kTurnTypePass,             // player passed their turn
  kTurnTypeExchange,         // player exchanged some tiles from their rack
  kTurnTypeResign,           // player resigned the match
  kTurnTypeDecline,          // player 2 declined match challenge
  kTurnTypeTimeout,          // player failed to act in time (rude!)
  kTurnTypeBomb
};

@interface Turn : NSObject

@property (nonatomic) int type;
@property (nonatomic) int playerNumber;              // Whose turn was it? {0,1}
@property (nonatomic) int matchState;                // state of match after turn
@property (nonatomic, copy) NSArray *wordsFormed;    // NSString objects
@property (nonatomic) int scoreDelta;
@property (nonatomic, copy) NSArray *bombsDetonatedAtCellIndices;

@end
