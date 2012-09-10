int modifierAt(int x, int y);
BOOL isTripleLetter(int index);
BOOL isTripleWord(int index);
BOOL isDoubleLetter(int index);
BOOL isDoubleWord(int index);
int starAt(int index);

int cellY(int index);
int cellX(int index);
int cellIndexFor(int x, int y);

BOOL isValidCell(int x, int y);
BOOL isValidCellIndex(int index);

#define kStartCellX 10
#define kStartCellY 10
#define kStartCellIndex cellIndexFor(kStartCellX, kStartCellY)

//#define kCellIndexForStar0 cellIndexFor(1,1)
//#define kCellIndexForStar1 cellIndexFor(19,1)
//#define kCellIndexForStar2 cellIndexFor(19,19)
//#define kCellIndexForStar3 cellIndexFor(1,19)
//#define kCellIndexForStar4 cellIndexFor(10,2)

#define kCellIndexForStar0 cellIndexFor(2,2)
#define kCellIndexForStar1 cellIndexFor(18,2)
#define kCellIndexForStar2 cellIndexFor(18,18)
#define kCellIndexForStar3 cellIndexFor(2,18)
#define kCellIndexForStar4 cellIndexFor(10,2)
