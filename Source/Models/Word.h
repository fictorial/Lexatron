@class Letter;

@interface Word : NSObject

@property (nonatomic, copy, readonly) NSArray *letters;

- (void)addLetter:(Letter *)letter;
- (int)score;
- (NSString *)string;
- (int)length;

@end
