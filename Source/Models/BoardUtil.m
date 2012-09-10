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

int modAtCellIndex(int cellIndex) {
  return modifierAt(cellX(cellIndex), cellY(cellIndex));
}

int modifierAt(int x, int y) {
  int index = cellIndexFor(x, y);

  if (index == kStartCellIndex)    return kModifierStart;
  if (index == kCellIndexForStar0) return kModifierStar0;
  if (index == kCellIndexForStar1) return kModifierStar1;
  if (index == kCellIndexForStar2) return kModifierStar2;
  if (index == kCellIndexForStar3) return kModifierStar3;
  if (index == kCellIndexForStar4) return kModifierStar4;

#define checkMod(mod, locs) \
for (int i=0; i < sizeof(locs)/sizeof(float); i += 2) \
  if (locs[i] == x && locs[i+1] == y) \
    return mod;

//  static float TLs[] = { 4,0, 16,0, 0,4, 20,4, 0,16, 20,16, 4,20, 16,20 };
//  static float DLs[] = { 7,7, 13,7, 7,13, 13, 13 };
//  static float DWs[] = { 4,4, 16,4, 4,16, 16,16  };
//  static float TWs[] = { 10,6, 10,14 };

  static float TLs[] = { 6,0, 14,0, 0,6, 20,6, 0,14, 20,14, 6,20, 14,20 };
  static float DLs[] = { 8,8, 12,8, 8,12, 12,12 };
  static float DWs[] = { 5,5, 15,5, 5,15, 15,15  };
  static float TWs[] = { 10,6, 10,14 };

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
  return modAtCellIndex(cellIndex) == kModifierDL;
}

BOOL isDoubleWord(int cellIndex) {
  return modAtCellIndex(cellIndex) == kModifierDW;
}

BOOL isTripleLetter(int cellIndex) {
  return modAtCellIndex(cellIndex) == kModifierTL;
}

BOOL isTripleWord(int cellIndex) {
  return modAtCellIndex(cellIndex) == kModifierTW;
}

BOOL isDeadZone(int tx, int ty) {
  static int locs[] = {
//    0,0, 2,0, 8,0, 10,0, 12,0, 18,0, 20,0,
//    9,1, 11,1,
//    0,2, 20,2,
//    0,8, 20,8,
//    1,9, 19,9,
//    0,10, 2,10, 18,10, 20,10,
//    1,11, 19,11,
//    0,12, 20,12,
//    0,18, 10,18, 20,18,
//    9,19, 11,19,
//    0,20, 2,20, 8,20, 10,20, 12,20, 18,20, 20,20

    0,0, 2,0, 4,0, 8,0, 10,0, 12,0, 16,0, 18,0, 20,0,
    1,1, 3,1, 9,1, 11,1, 17,1, 19,1,
    0,2, 20,2,
    1,3, 19,3,
    0,4, 20,4,
    0,8, 20,8,
    1,9, 19,9,
    0,10, 2,10, 18,10, 20,10,
    1,11, 19,11,
    0,12, 20,12,
    0,16, 20,16,
    1,17, 19,17,
    0,18, 10,18, 20,18,
    1,19, 3,19, 9,19, 11,19, 17,19, 19,19,
    0,20, 2,20, 4,20, 8,20, 10,20, 12,20, 16,20, 18,20, 20,20
  };

  for (int i=0; i < sizeof(locs)/sizeof(float); i += 2)
    if (locs[i] == tx && locs[i+1] == ty)
      return YES;

  return NO;
}

int starAt(int index) {
  int mod = modAtCellIndex(index);
  if (mod >= kModifierStar0 && mod <= kModifierStar4)
    return mod - kModifierStar0;
  return -1;
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
