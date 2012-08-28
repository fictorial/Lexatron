#import "BoardUtil.h"
#import "MatchConstants.h"

int cellY(int cellIndex) {
  return (cellIndex < 0) ? -1 : cellIndex / kBoardSize;
}

int cellX(int cellIndex) {
  return (cellIndex < 0) ? -1 : cellIndex % kBoardSize;
}

int cellIndexFor(int x, int y) {
  return y * kBoardSize + x;
}

int modifierAtcellIndexFor(int cellIndex) {
  return modifierAt(cellX(cellIndex), cellY(cellIndex));
}

int modifierAt(int x, int y) {
  if (x == 0 && y == kBoardSize-1)
    return kModifierFirstPlayerStart;

  if (x == kBoardSize-1 && y == 0)
    return kModifierFirstPlayerEnd;

  if (x == 0 && y == 0)
    return kModifierSecondPlayerStart;

  if (x == kBoardSize-1 && y == kBoardSize-1)
    return kModifierSecondPlayerEnd;

  if ((x == 6 && y == 14) || (x == 22 && y == 14))
    return kModifierMystery;

#define checkMod(mod, locs) \
for (int i=0; i < sizeof(locs)/sizeof(float); i += 2) \
  if (locs[i] == x && locs[i+1] == y) \
    return mod;

  static float TLs[] = {0,8, 8,0, 8,8, 20,8, 20,0, 28,8, 0,20, 8,20, 8,28, 20,20, 20,28, 28,20};
  static float DLs[] = {2,6, 6,2, 6,6, 6,10, 10,6, 12,12, 16,16, 18,6, 22,10, 22,6, 22,2, 26,6, 6,18, 2,22, 6,22, 10,22, 6,26, 22,18, 18,22, 22,22, 26,22, 22,26 };
  static float DWs[] = {4,4, 24,4, 16,12, 12,16, 4,24, 24,24};
  static float TWs[] = {14,8, 14,20};

  checkMod(kModifierTL, TLs);
  checkMod(kModifierDL, DLs);
  checkMod(kModifierDW, DWs);
  checkMod(kModifierTW, TWs);

  return kModifierNone;
}

int letterValue(int letter) {
  //assert((letter >= 'A' && letter <= 'Z') || letter == ' ');

if ((letter < 'A' || letter > 'Z') && letter != ' ')
  return 0;

  if (letter == ' ')
    return 0;

  // ---------------------> A B C D E F G H I J  K L M N O P Q  R S T U V W X Y Z
  static int points[26] = { 1,4,5,2,1,4,3,3,1,10,5,2,5,2,1,4,10,1,1,1,2,5,4,8,3,10 };
  return points[letter - 'A'];
}

BOOL isDoubleLetter(int cellIndex) {
  return modifierAtcellIndexFor(cellIndex) == kModifierDL;
}

BOOL isDoubleWord(int cellIndex) {
  return modifierAtcellIndexFor(cellIndex) == kModifierDW;
}

BOOL isTripleLetter(int cellIndex) {
  return modifierAtcellIndexFor(cellIndex) == kModifierTL;
}

BOOL isTripleWord(int cellIndex) {
  return modifierAtcellIndexFor(cellIndex) == kModifierTW;
}

BOOL isMystery(int cellIndex) {
  return modifierAtcellIndexFor(cellIndex) == kModifierMystery;
}

BOOL isDeadZone(int tx, int ty) {
  BOOL dead = NO;

  switch (ty) {
    case 0:  case 28: dead = (tx >= 10 && tx < 19); break;
    case 1:  case 27: dead = (tx >= 11 && tx < 18); break;
    case 2:  case 26: dead = (tx >= 12 && tx < 17); break;
    case 3:  case 25: dead = (tx >= 13 && tx < 16); break;
    case 4:  case 24: dead = (tx == 14);            break;
    case 10: case 19: dead = (tx < 1 || tx > 27);   break;
    case 11: case 18: dead = (tx < 2 || tx > 26);   break;
    case 12: case 17: dead = (tx < 3 || tx > 25);   break;
    case 13: case 16: dead = (tx < 4 || tx > 24);   break;
    case 14: case 15: dead = (tx < 5 || tx > 23);   break;
  }

  return dead;
}

BOOL isValidCellIndex(int cellIndex) {
  return isValidCell(cellX(cellIndex), cellY(cellIndex));
}

BOOL isValidCell(int x, int y) {
  return (x >= 0 &&
          y >= 0 &&
          x < kBoardSize &&
          y < kBoardSize &&
          !isDeadZone(x, y));
}
