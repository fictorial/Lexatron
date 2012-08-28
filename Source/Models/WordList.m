#import "WordList.h"
#import "Word.h"

NSString * const kWordListFile = @"WordList.txt";

enum {
  kWordListWordCount = 180000
};

@implementation WordList {
  NSMutableSet *_words;
}

+ (WordList *)sharedWordList {
  static dispatch_once_t once;
  static id sharedInstance;

  dispatch_once(&once, ^{
    sharedInstance = [[self alloc] init];
  });

  return sharedInstance;
}

- (id)init {
  self = [super init];

  if (self) {
    NSURL *url = [NSBundle.mainBundle URLForResource:kWordListFile withExtension:nil];

    NSData *fileData = [NSData dataWithContentsOfURL:url];

    if (!fileData) {
      DLog(@"failed to load '%@'", kWordListFile);
      return nil;
    }

    DLog(@"word list: loading...");

    NSString *fileAsString = [NSString stringWithUTF8String:fileData.bytes];
    _words = [NSMutableSet setWithCapacity:kWordListWordCount];
    [fileAsString enumerateLinesUsingBlock:^(NSString *word, BOOL *stop) {
      [_words addObject:word];
    }];

    NSAssert(_words.count > 0, @"empty dictionary file?");
    DLog(@"word list: loaded %d words", _words.count);
  }

  return self;
}

- (BOOL)contains:(Word *)word {
  return [_words containsObject:[[word string] lowercaseString]];
}

@end

