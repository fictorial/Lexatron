@class Word;

@interface WordList : NSObject

+ (WordList *)sharedWordList;
- (BOOL)contains:(Word *)word;

@end

