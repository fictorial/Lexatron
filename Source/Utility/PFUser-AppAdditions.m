#import "PFUser-AppAdditions.h"
#import "MatchLogic.h"
#import "NSDictionary-Convenience.h"

// https://parse.com/questions/error-102-bad-special-key-__type-say-what
// If you drop the Match class, set this to 1, start and save a match.
// Then set it back to 0 and run again. *sigh*
#define WORKAROUND_PARSE_NO_CLASS_ERROR 0

static NSString * const kBlockedUsersKey = @"blockedUsers";

@implementation PFUser (AppAdditions)

- (NSString *)usernameForDisplay {
  NSString *displayName = [self objectForKey:@"displayName"];
  if (displayName)
    return displayName;
  
  return self.username;    
}

- (BOOL)blocks:(PFUser *)user {
  NSArray *blockedUserIDs = [self objectForKey:kBlockedUsersKey];  
  if (!blockedUserIDs)
    return NO;  
  return [blockedUserIDs containsObject:user.objectId];
}

- (void)block:(PFUser *)user {
  NSMutableArray *blockedUserIDs = [[self objectForKey:kBlockedUsersKey] mutableCopy];  
  if (!blockedUserIDs) {
    blockedUserIDs = [@[user.objectId] mutableCopy];
  } else if (![blockedUserIDs containsObject:user.objectId]) {
    [blockedUserIDs addObject:user.objectId];
  }  
  [self setObject:blockedUserIDs forKey:kBlockedUsersKey];
}

- (void)unblock:(PFUser *)user {
  NSMutableArray *blockedUserIDs = [[self objectForKey:kBlockedUsersKey] mutableCopy];
  if ([blockedUserIDs containsObject:user.objectId]) {  
    [blockedUserIDs removeObject:user.objectId];
    [self setObject:blockedUserIDs forKey:kBlockedUsersKey];
  }
}

// Error: Channel name must start with a letter: 2647BeHWZ3 (Code: 112, Version: 1.0.49)
// Thus, we use 'u' + user's object ID

- (NSString *)pushChannelName {
  return [@"u" stringByAppendingString:self.objectId];
}

- (void)countOfActiveMatches:(PFIntegerResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(0,nil);
  return;
#endif

  [PFCloud callFunctionInBackground:@"activeMatchCount" withParameters:@{} block:^(id object, NSError *error) {
    if (error) {
      DLog(@"CloudCode error => %@", [error localizedDescription]);
      block(-1, error);
      return;
    }

    DLog(@"actionableMatches via CloudCode => %@", object);
    block([object intValue], nil);
  }];
}

- (void)actionableMatches:(PFArrayResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(@[],nil);
  return;
#endif

  [PFCloud callFunctionInBackground:@"actionableMatches" withParameters:@{} block:^(id object, NSError *error) {
    if (error) {
      DLog(@"CloudCode error => %@", [error localizedDescription]);
      block(nil, error);
      return;
    }

    DLog(@"CloudCode => %@", object);
    block(object, nil);
  }];
}

- (void)unactionableMatches:(PFArrayResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(@[],nil);
  return;
#endif

  [PFCloud callFunctionInBackground:@"unactionableMatches" withParameters:@{} block:^(id object, NSError *error) {
    if (error) {
      DLog(@"CloudCode error => %@", [error localizedDescription]);
      block(nil, error);
      return;
    }

    DLog(@"CloudCode => %@", object);
    block(object, nil);
  }];
}

- (void)completedMatches:(PFArrayResultBlock)block {
  [PFCloud callFunctionInBackground:@"completedMatches" withParameters:@{} block:^(id object, NSError *error) {
    if (error) {
      DLog(@"CloudCode error => %@", [error localizedDescription]);
      block(nil, error);
      return;
    }

    DLog(@"CloudCode => %@", object);
    block(object, nil);
  }];
}

- (void)getRecord:(DictResultBlock)block {
  [PFCloud callFunctionInBackground:@"getRecord" withParameters:@{} block:^(id object, NSError *error) {
    if (error) {
      DLog(@"CloudCode error => %@", [error localizedDescription]);
      block(nil, error);
      return;
    }

    DLog(@"CloudCode => %@", object);
    block(object, nil);
  }];
}

@end