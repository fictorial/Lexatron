#import "Word.h"
#import "Letter.h"
#import "BoardUtil.h"

@interface Word ()
@property (nonatomic, copy, readwrite) NSArray *letters;
@end

@implementation Word {
@public
  NSMutableArray *_letters;
}

- (id)init {
  self = [super init];

  if (self) {
    _letters = [NSMutableArray arrayWithCapacity:3];
  }

  return self;
}

- (void)addLetter:(Letter *)letter {
  [_letters addObject:letter];
}

- (int)score {
  int wordScore = 0, twCount = 0, dwCount = 0;

  for (Letter *letter in _letters) {
    int letterScore = [letter score];
    wordScore += letterScore;

    DLog(@"word scoring '%@': letter score for '%c' = %d (letterValue=%d, isTL=%d isDL=%d isMystery=%d)",
         [self string], letter.letter, letterScore, letterValue(letter.letter),
         isTripleLetter(letter.cellIndex), isDoubleLetter(letter.cellIndex), isMystery(letter.cellIndex));

    if (letter.turnNumber == -1) {  // modifiers are only effective on first-use.
      if (isTripleWord(letter.cellIndex))
        twCount++;
      else if (isDoubleWord(letter.cellIndex))
        dwCount++;
    }
  }

  DLog(@"word scoring: '%@' ... base score = %d, TWs = %d, DWs = %d", [self string], wordScore, twCount, dwCount);

  if (dwCount > 0)
    wordScore *= pow(2, dwCount);

  if (twCount > 0)
    wordScore *= pow(3, twCount);

  return wordScore;
}

- (NSString *)string {
  NSMutableString *str = [NSMutableString stringWithCapacity:_letters.count];

  [_letters each:^(id sender) {
    Letter *letter = sender;
    [str appendFormat:@"%c", [letter effectiveLetter]];
  }];

  return str;
}

- (int)length {
  return _letters.count;
}

- (BOOL)isEqual:(id)object {
  if (object == self)
    return YES;

  if ([self class] != [object class])
    return NO;

  Word *word = object;
  return [_letters isEqual:word->_letters];
}

- (NSUInteger)hash {
  NSUInteger h = 0;
  for (Letter *letter in _letters)
    h ^= [letter hash];
  return h;
}

@end
