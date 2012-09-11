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

#pragma mark - match helpers

// The current user is either the first or second player and the current player is the same.

- (PFQuery *)queryForMyTurn:(BOOL)myTurn {
  int currentNumber = myTurn ? 0 : 1;
  int otherNumber = myTurn ? 1 : 0;
  
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"currentPlayerNumber" equalTo:@(currentNumber)];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateActive), @(kMatchStatePending)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"currentPlayerNumber" equalTo:@(otherNumber)];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateActive), @(kMatchStatePending)]];

  PFQuery *orQuery = [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
  [orQuery orderByDescending:@"updatedAt"];

  return orQuery;
}

// The current user is either the first or second player but we don't care whose turn it is.

- (PFQuery *)queryForActiveMatches {
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateActive), @(kMatchStatePending)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateActive), @(kMatchStatePending)]];

  return [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
}

- (void)countOfActiveMatches:(PFIntegerResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(0,nil);
  return;
#endif

  DLog(@"getting count of active matches...");

  PFQuery *query = [self queryForActiveMatches];

  // do not include firstPlayer/secondPlayer since we just want the count here.

  [query countObjectsInBackgroundWithBlock:block];
}

- (PFQuery *)actionableQuery {
  PFQuery *query = [self queryForMyTurn:YES];

  [query includeKey:@"firstPlayer"];
  [query includeKey:@"secondPlayer"];

  return query;
}

- (PFQuery *)unactionableQuery {
  PFQuery *query = [self queryForMyTurn:NO];

  [query includeKey:@"firstPlayer"];
  [query includeKey:@"secondPlayer"];

  return query;
}

- (void)countOfActionableMatches:(PFIntegerResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(0,nil);
  return;
#endif

  DLog(@"getting count of actionable matches...");

  PFQuery *query = [self queryForMyTurn:YES];

  // do not include firstPlayer/secondPlayer since we just want the count here.

  [query countObjectsInBackgroundWithBlock:block];
}

- (void)actionableMatches:(PFArrayResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(@[],nil);
  return;
#endif

  PFQuery *query = [self actionableQuery];
  [query findObjectsInBackgroundWithBlock:block];
}

- (void)unactionableMatches:(PFArrayResultBlock)block {
#if WORKAROUND_PARSE_NO_CLASS_ERROR
  block(@[],nil);
  return;
#endif

  PFQuery *query = [self unactionableQuery];
  [query findObjectsInBackgroundWithBlock:block];
}

- (void)completedMatches:(PFArrayResultBlock)block {
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *orQuery = [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
  [orQuery orderByDescending:@"updatedAt"];  // want newest COMPLETED matches first.
  [orQuery includeKey:@"firstPlayer"];
  [orQuery includeKey:@"secondPlayer"];
  orQuery.limit = 50;
  [orQuery findObjectsInBackgroundWithBlock:block];
}

- (void)countOfMatchesWon:(PFIntegerResultBlock)block {
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"winningPlayer" equalTo:@(0)];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"winningPlayer" equalTo:@(1)];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *orQuery = [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
  [orQuery countObjectsInBackgroundWithBlock:block];
}

- (void)countOfMatchesLost:(PFIntegerResultBlock)block {
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"losingPlayer" equalTo:@(0)];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"losingPlayer" equalTo:@(1)];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *orQuery = [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
  [orQuery countObjectsInBackgroundWithBlock:block];
}

- (void)countOfMatchesTied:(PFIntegerResultBlock)block {
  PFQuery *firstPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [firstPlayerQuery whereKey:@"firstPlayer" equalTo:self];
  [firstPlayerQuery whereKey:@"losingPlayer" equalTo:@(-1)];
  [firstPlayerQuery whereKey:@"winningPlayer" equalTo:@(-1)];
  [firstPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *secondPlayerQuery = [PFQuery queryWithClassName:@"Match"];
  [secondPlayerQuery whereKey:@"secondPlayer" equalTo:self];
  [secondPlayerQuery whereKey:@"losingPlayer" equalTo:@(-1)];
  [secondPlayerQuery whereKey:@"winningPlayer" equalTo:@(-1)];
  [secondPlayerQuery whereKey:@"state" containedIn:@[@(kMatchStateEndedNormal), @(kMatchStateEndedResign), @(kMatchStateEndedTimeout)]];

  PFQuery *orQuery = [PFQuery orQueryWithSubqueries:@[firstPlayerQuery, secondPlayerQuery]];
  [orQuery countObjectsInBackgroundWithBlock:block];
}


@end