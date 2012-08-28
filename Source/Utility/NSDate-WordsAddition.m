#import "NSDate-WordsAddition.h"

@implementation NSDate (WordsAddition)

- (NSString *)timeAgoInWords {
  NSTimeInterval intervalInSeconds = [[NSDate date] timeIntervalSinceDate:self];  // receiver later so timeInterval > 0  
  NSTimeInterval intervalInMinutes = round(intervalInSeconds / 60.0f);
  
  if (intervalInMinutes >= 0 && intervalInMinutes <= 1)
    return intervalInMinutes <= 0 ? NSLocalizedString(@"less than a minute ago", nil) : NSLocalizedString(@"a minute ago", nil);
  
  if (intervalInMinutes >= 2 && intervalInMinutes <= 44)
    return [NSString stringWithFormat:NSLocalizedString(@"%d minutes ago", nil), (NSInteger)intervalInMinutes];
  
  if (intervalInMinutes >= 45 && intervalInMinutes <= 89)
    return NSLocalizedString(@"about an hour ago", nil);
  
  if (intervalInMinutes >= 90 && intervalInMinutes <= 1439)
    return [NSString stringWithFormat:NSLocalizedString(@"about %d hours ago", nil), (NSInteger)round(intervalInMinutes / 60.0f)];
  
  if (intervalInMinutes >= 1440 && intervalInMinutes <= 2879)
    return NSLocalizedString(@"a day ago", nil);
  
  if (intervalInMinutes >= 2880 && intervalInMinutes <= 43199)
    return [NSString stringWithFormat:NSLocalizedString(@"%d days ago", nil), (NSInteger)round(intervalInMinutes / 1440.0f)];
  
  if (intervalInMinutes >= 43200 && intervalInMinutes <= 86399)
    return NSLocalizedString(@"about a month ago", nil);
  
  if (intervalInMinutes >= 86400 && intervalInMinutes <= 525599)
    return [NSString stringWithFormat:NSLocalizedString(@"%d months ago", nil), (NSInteger)round(intervalInMinutes / 43200.0f)];
  
  if (intervalInMinutes >= 525600 && intervalInMinutes <= 1051199)
    return NSLocalizedString(@"about a year ago", nil);

  return [NSString stringWithFormat:NSLocalizedString(@"a very long time ago", nil), (NSInteger)round(intervalInMinutes / 525600.0f)];
}

@end