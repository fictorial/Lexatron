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

#define kStartCellIndexForFirstPlayer  cellIndexFor(2,2)
#define kStartCellIndexForSecondPlayer cellIndexFor(2,18)
#define kEndCellIndexForFirstPlayer    cellIndexFor(18,18)
#define kEndCellIndexForSecondPlayer   cellIndexFor(18,2)
