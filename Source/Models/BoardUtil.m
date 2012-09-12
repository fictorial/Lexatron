#import "BoardUtil.h"

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
  if (x == 0 && y == 0)
    return kModifierFirstPlayerStart;

  if (x == kBoardSize-1 && y == kBoardSize-1)
    return kModifierFirstPlayerEnd;

  if (x == 0 && y == kBoardSize-1)
    return kModifierSecondPlayerStart;

  if (x == kBoardSize-1 && y == 0)
    return kModifierSecondPlayerEnd;

  if ((x == 2 && y == 10) || (x == 18 && y == 10))
    return kModifierMystery;

#define checkMod(mod, locs) \
for (int i=0; i < sizeof(locs)/sizeof(float); i += 2) \
  if (locs[i] == x && locs[i+1] == y) \
    return mod;

  static float TLs[] = {
    6,0,  14,0,
    0,6,  20,6,
    0,14, 20,14,
    6,20, 14,20
  };

  static float DLs[] = {
    8,8, 12,8,
    8,12, 12,12
  };

  static float DWs[] = {
    5,5, 15,5,
    5,15, 15,15
  };

  static float TWs[] = {
    10,2,
    10,10,
    10,18
  };

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
  static int locs[] = {
    8,0, 10,0, 12,0,
    9,1, 11,1,
    0,8, 0,10, 0,12,
    1,9, 1,11,
    19,9, 19,11,
    20,8, 20,10, 20,12,
    9,19, 11,19,
    8,20, 10,20, 12,20
  };

  for (int i=0; i < sizeof(locs)/sizeof(float); i += 2)
    if (locs[i] == tx && locs[i+1] == ty)
      return YES;

  return NO;
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
