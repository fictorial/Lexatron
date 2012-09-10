enum {
  kRackTileCount = 7,
  kBoardSize = 21,
  kBoardCellCount = kBoardSize*kBoardSize,
  kBingoBonusPoints = 50
};

enum {
  kMatchStatePending,        // challenge
  kMatchStateEndedDeclined,  // challenge rejected
  kMatchStateActive,         // challenge accepted
  kMatchStateEndedNormal,    // match ended normally
  kMatchStateEndedResign,    // match ended with player resignation
  kMatchStateEndedTimeout    // match ended since player failed to act (rude!)
};

enum {
  kModifierNone,
  kModifierStart,
  kModifierDL,
  kModifierTL,
  kModifierDW,
  kModifierTW,
  kModifierStar0,
  kModifierStar1,
  kModifierStar2,
  kModifierStar3,
  kModifierStar4
};

enum {
  kBoardDirectionSW,
  kBoardDirectionNE,
  kBoardDirectionNW,
  kBoardDirectionSE
};

extern NSString * const kTurnDidEndNotification;
extern NSString * const kPassAndPlayDefaultsKey;

