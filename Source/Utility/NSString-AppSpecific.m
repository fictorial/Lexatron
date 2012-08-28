#import "RegexKitLite.h"

#import "NSString-AppSpecific.h"

static NSString * const kEmailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";

@implementation NSString (AppAdditions)

- (NSString *)trimWhitespace {
  return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)isNonEmptyStringWithName:(NSString *)name
                             minLength:(NSUInteger)minLength
                             maxLength:(NSUInteger)maxLength {

  DLog(@"input:%@ min:%u max:%u", self, minLength, maxLength);

  if (self.length < minLength || self.length > maxLength) {
    if (maxLength == NSUIntegerMax) {
      NSString *errorFormat = NSLocalizedString(@"%@ must be at least %u characters long", nil);
      return [NSString stringWithFormat:errorFormat, name, minLength];
    }

    NSString *errorFormat = NSLocalizedString(@"%@ must be between %u and %u characters in length", nil);
    return [NSString stringWithFormat:errorFormat, name, minLength, maxLength];
  }
  return nil;
}

- (NSString *)checkValidUsername {
  NSString *error = [self isNonEmptyStringWithName:NSLocalizedString(@"Username", nil)
                                         minLength:kMinUsernameLength
                                         maxLength:kMaxUsernameLength];

  if (error)
    return error;

  // note the use of UNICODE regex matchers for the concept of 'letter' and 'number'

  BOOL isMatch = [self isMatchedByRegex:@"^\\p{L}+[\\p{L}\\p{N}_]+$"];

  if (!isMatch) {
    return NSLocalizedString(@"Your username must begin with a letter and may only contain letters, numbers and underscores.", nil);
  }

  return nil;
}

- (NSString *)checkValidPassword {
  return [self isNonEmptyStringWithName:NSLocalizedString(@"Passwords", @"Passwords")
                              minLength:kMinPasswordLength
                              maxLength:NSUIntegerMax];
}

- (NSString *)checkValidEmail {
  NSString *email = [self trimWhitespace];

  if (email.length == 0)
    return nil;   // optional
  //        return NSLocalizedString(@"An email address is required", nil);

  if ([[NSPredicate predicateWithFormat:@"SELF MATCHES %@", kEmailRegex] evaluateWithObject:email])
    return nil;

  return NSLocalizedString(@"Please enter a valid e-mail address.", nil);
}

@end
