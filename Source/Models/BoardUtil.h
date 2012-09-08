int modifierAt(int x, int y);
BOOL isTripleLetter(int index);
BOOL isTripleWord(int index);
BOOL isDoubleLetter(int index);
BOOL isDoubleWord(int index);
BOOL isMystery(int index);

int cellY(int index);
int cellX(int index);
int cellIndexFor(int x, int y);

BOOL isValidCell(int x, int y);
BOOL isValidCellIndex(int index);

// order defined: NW, SE, NW, SE

#define kStartCellXForFirstPlayer   0
#define kStartCellYForFirstPlayer   0
#define kStartCellXForSecondPlayer  0
#define kStartCellYForSecondPlayer  (kBoardSize-1)

#define kEndCellXForFirstPlayer     (kBoardSize-1)
#define kEndCellYForFirstPlayer     (kBoardSize-1)
#define kEndCellXForSecondPlayer    (kBoardSize-1)
#define kEndCellYForSecondPlayer    0

#define kStartCellIndexForFirstPlayer  cellIndexFor(kStartCellXForFirstPlayer, kStartCellYForFirstPlayer)
#define kStartCellIndexForSecondPlayer cellIndexFor(kStartCellXForSecondPlayer, kStartCellYForSecondPlayer)
#define kEndCellIndexForFirstPlayer    cellIndexFor(kEndCellXForFirstPlayer, kEndCellYForFirstPlayer)
#define kEndCellIndexForSecondPlayer   cellIndexFor(kEndCellXForSecondPlayer, kEndCellYForSecondPlayer)
