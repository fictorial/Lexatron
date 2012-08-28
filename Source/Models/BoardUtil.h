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

#define kStartCellIndexForFirstPlayer  0
#define kStartCellIndexForSecondPlayer kBoardSize*(kBoardSize-1)
#define kEndCellIndexForFirstPlayer    cellIndexFor(kBoardSize-1, kBoardSize-1)
#define kEndCellIndexForSecondPlayer   cellIndexFor(kBoardSize-1, 0)
