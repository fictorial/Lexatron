int letterValue(int letter);

@interface Letter : NSObject <NSCopying>

@property (nonatomic) int cellIndex;         // -1 if not on board; else [0,360)
@property (nonatomic) int rackIndex;         // -1 if not on rack; else [0,7)
@property (nonatomic) int playerOwner;       // Who owns this item? {0,1}
@property (nonatomic) int turnNumber;        // In what turn was this placed?
@property (nonatomic) int letter;            // [A-Z ]
@property (nonatomic) int substituteLetter;  // [A-Z] chosen letter by user when letter==' '

+ (id)letter:(int)letter;
- (int)score;
- (int)effectiveLetter;                      // letter if non-blank else substituteLetter
- (BOOL)isBlank;
- (BOOL)isBomb;

@end

