#import "Letter.h"
#import "BoardUtil.h"

@implementation Letter

+ (id)letter:(int)letterValue {
  Letter *letter = [[Letter alloc] init];
  letter.letter = letterValue;
  return letter;
}

- (id)init {
  self = [super init];

  if (self) {
    _cellIndex = _rackIndex = _turnNumber = _playerOwner = -1;
  }

  return self;
}

- (int)score {
  int val = letterValue(_letter);

  if (_turnNumber != -1)  // multipliers only effective on first-use
    return val;

  if (isDoubleLetter(_cellIndex))
    return val * 2;

  if (isTripleLetter(_cellIndex))
    return val * 3;

  if (isMystery(_cellIndex))
    return val + 25;

  return val;
}

- (int)effectiveLetter {
  return (_letter == ' ') ? _substituteLetter : _letter;
}

- (BOOL)isEqual:(id)object {
  if (object == self)
    return YES;

  if ([self class] != [object class])
    return NO;

  Letter *item = object;

  return (_cellIndex == item->_cellIndex &&
          _rackIndex == item->_rackIndex &&
          _playerOwner == item->_playerOwner &&
          _turnNumber == item->_turnNumber &&
          _substituteLetter == item->_substituteLetter);
}

- (NSUInteger)hash {
  return _cellIndex ^ _rackIndex ^ _playerOwner ^ _letter ^ _substituteLetter;
}

- (NSString *)description {
  NSMutableString *str = [NSMutableString stringWithFormat:@"board-cell=%d (%d,%d) rack-cell=%d owner=%d turn=%d",
                          _cellIndex, cellX(_cellIndex), cellY(_cellIndex), _rackIndex, _playerOwner, _turnNumber];

  if (_letter == ' ')
    [str appendFormat:@" letter=(%c)", _letter];
  else
    [str appendFormat:@" letter=%c", _letter];

  return str;
}

- (id)copyWithZone:(NSZone *)zone {
  Letter *aLetter = [[Letter allocWithZone:zone] init];
  aLetter.cellIndex = _cellIndex;
  aLetter.rackIndex = _rackIndex;
  aLetter.letter = _letter;
  aLetter.substituteLetter = _substituteLetter;
  aLetter.playerOwner = _playerOwner;
  aLetter.turnNumber = _turnNumber;
  return aLetter;
}

@end
