//
//  FindOpponentViewController.m
//  letterquest
//
//  Created by Brian Hammond on 8/5/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "FindOpponentViewController.h"
#import "MatchLogic.h"
#import "MatchViewController.h"
#import "KNMultiItemSelector.h"
#import "ABContactsHelper.h"
#import "ATMHud.h"
#import "PromptViewController.h"
#import "LQAudioManager.h"

#import <Twitter/Twitter.h>

typedef enum {
  kSelectorModeNone,
  kSelectorModeContacts,
  kSelectorModeFacebook,
  kSelectorModeRematch
} SelectorMode;

@interface FindOpponentViewController ()

@property (nonatomic, strong) UIButton *randomButton;
@property (nonatomic, strong) UIButton *rematchButton;
@property (nonatomic, strong) UIButton *facebookButton;
@property (nonatomic, strong) UIButton *contactsButton;
@property (nonatomic, strong) UIButton *usernameButton;
@property (nonatomic, strong) UIButton *passAndPlayButton;
@property (nonatomic, strong) UIButton *tweetButton;
@property (nonatomic, assign) SelectorMode selectorMode;                   // What is the user selector being used for?

@end

@implementation FindOpponentViewController {
  PF_FBRequest *facebookIdRequest;             // Get authorized Facebook user's ID
  PF_FBRequest *facebookFriendsRequest;        // Get authorized Facebook user's friends
  NSArray *allFacebookFriends;                 // Facebook user dictionaries
  NSArray *usersWithAppInstalledFromFacebook;  // PFUser objects
}

- (void)loadView {
  self.title = @"Find a friend to play";
  [super loadView];

  float w = self.view.bounds.size.width;
  float h = [self effectiveViewHeight];
  float cy = h/2;
  float pad = SCALED(20);
  float lx = w/3.33;
  float rx = w-w/3.33;

  self.randomButton = [self addButtonWithTitle:@"Random"
                                         color:kGlossyGreenColor
                                      selector:@selector(doRandom:)
                                        center:CGPointMake(lx, cy-kGlossyButtonHeight*1.25-pad)];

  self.facebookButton = [self addButtonWithTitle:@"Facebook"
                                           color:kGlossyBlueColor
                                        selector:@selector(doFacebook:)
                                          center:CGPointMake(rx, cy-kGlossyButtonHeight*1.25-pad)];

  self.usernameButton = [self addButtonWithTitle:@"Username"
                                           color:kGlossyPurpleColor
                                        selector:@selector(doUsername:)
                                          center:CGPointMake(lx, cy)];

  self.rematchButton = [self addButtonWithTitle:@"Rematch"
                                          color:kGlossyLightBlueColor
                                       selector:@selector(doRematch:)
                                         center:CGPointMake(rx, cy)];

  self.contactsButton = [self addButtonWithTitle:@"Contacts"
                                           color:kGlossyOrangeColor
                                        selector:@selector(doContacts:)
                                          center:CGPointMake(lx, cy+kGlossyButtonHeight*1.25+pad)];

  self.passAndPlayButton = [self addButtonWithTitle:@"Pass & Play"
                                              color:kGlossyGoldColor
                                           selector:@selector(doPassAndPlay:)
                                             center:CGPointMake(rx, cy+kGlossyButtonHeight*1.25+pad)];

  [_passAndPlayButton setTitleColor:kGlossyBrownColor forState:UIControlStateNormal];
  _passAndPlayButton.titleLabel.shadowOffset = CGSizeZero;

  self.tweetButton = [[UIButton alloc] initWithFrame:CGRectZero];
  UIImage *twitterImage = [UIImage imageWithName:@"twitter"];
  [_tweetButton setImage:twitterImage forState:UIControlStateNormal];
  [_tweetButton sizeToFit];
  [_tweetButton addTarget:self action:@selector(playButtonSound:) forControlEvents:UIControlEventTouchUpInside];
  [_tweetButton addTarget:self action:@selector(doTweetInvite:) forControlEvents:UIControlEventTouchUpInside];
  _tweetButton.center = CGPointMake(w/2, h - twitterImage.size.height/2 - SCALED(2));
  [self.view addSubview:_tweetButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  PFUser *currentUser = [PFUser currentUser];
  if (currentUser && currentUser.isAuthenticated) {
    _tweetButton.hidden = ![TWTweetComposeViewController canSendTweet];
  } else {
    _tweetButton.hidden = YES;
  }

  if (![self isShowingHUD])
    [self slideInButtons];
}

- (void)viewDidAppear:(BOOL)animated {
  [self hideActivityHUD];
  [super viewDidAppear:animated];
}

- (void)slideInButtons {
  [self slideInFromLeft:@[_randomButton, _contactsButton, _usernameButton]];
  [self slideInFromRight:@[_rematchButton, _facebookButton, _passAndPlayButton]];
  [[LQAudioManager sharedManager] playEffect:kEffectSlide];
}

- (void)slideInFromLeft:(NSArray *)views {
  for (id view in views)
    [view backInFrom:kFTAnimationLeft withFade:YES duration:0.5 delegate:nil];
}

- (void)slideInFromRight:(NSArray *)views {
  for (id view in views)
    [view backInFrom:kFTAnimationRight withFade:YES duration:0.5 delegate:nil];
}

#pragma mark - random opponent

/*
 Player doesn't care with whom they play; system is to find a random opponent.

 Some issues with Parse cause us some grief:

 - you cannot update and save to other users besides the logged-in local user
 - you download snapshots of objects, edit locally, and store back which cause
 race conditions and potentially overwrites

 The algorithm is as follows:

 - if the current user has 3 matches waiting a random opponent
 - stop

 - query for Match where key 'setupRandom' exists and key 'suitors' does not exist.
 - limit to 24 matches

 - if none found:
 - create a Match object
 - set 'secondPlayer' to currentUser
 - set 'setupRandom' to YES
 - show alert to user that says "we're searching for random opponent"
 - stop

 - while there are candidate matches to try and join:
 - grab the next candidate match
 - atomically add-unique the currentUser's objectId to the match's 'suitors' key
 - save the Match
 - refresh the Match
 - if first objectId in 'suitors' is currentUser:
 - won the race and can join the match
 - set currentUser as 'firstPlayer'
 - remove key 'setupRandom' and 'suitors'
 - save the match
 - load the match into the match VC
 - stop
 */

- (void)doRandom:(id)sender {
  if (!REQUIRE_USER)
    return;

  [TestFlight passCheckpoint:@"findByRandom"];

  [self showActivityHUD];

  __weak id weakSelf = self;

  [self startTimeoutTimer];

  // Does this user already have a random match awaiting suitors?

  PFQuery *query = [PFQuery queryWithClassName:@"Match"];
  [query whereKey:@"state" equalTo:[NSNumber numberWithInt:kMatchStatePending]];
  [query whereKeyExists:@"setupRandom"];
  [query whereKey:@"secondPlayer" equalTo:[PFUser currentUser]];
  [query countObjectsInBackgroundWithBlock:^(int number, NSError *error) {
    [weakSelf removeTimeoutTimer];
    
    BOOL stop = (error || number > 0);

    if (error)
      [error showParseError:NSLocalizedString(@"search", nil)];

    if (stop) {
      DLog(@"not continuing with random match search/setup (existing:%d; error:%@)", number, [error localizedDescription]);

      [weakSelf showWaitingForRandomOpponentAlert];
      [weakSelf hideActivityHUD];
      return;
    }

    [weakSelf startTimeoutTimer];

    // No existing random match by this user; find matches waiting for a random opponent.

    PFQuery *randomMatchesQuery = [PFQuery queryWithClassName:@"Match"];
    [randomMatchesQuery whereKey:@"state" equalTo:[NSNumber numberWithInt:kMatchStatePending]];
    [randomMatchesQuery whereKeyExists:@"setupRandom"];
    [randomMatchesQuery whereKeyDoesNotExist:@"suitors"];
    [randomMatchesQuery orderByAscending:@"createdAt"];  // oldest first (FIFO)
    [randomMatchesQuery includeKey:@"secondPlayer"];     // if we win the suitor race, we'll show the match so we need the opp.
    randomMatchesQuery.limit = 20;                       // assume we'll lose the race < 20 times!
    [randomMatchesQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
      [weakSelf removeTimeoutTimer];
      
      if (error) {
        [error showParseError:NSLocalizedString(@"search", nil)];
        [weakSelf hideActivityHUD];
        return;
      }

      DLog(@"random: found %d candidate matches", objects.count);

      if (objects.count == 0) {
        [weakSelf makeMatchWaitingForRandomOpponent];
      } else {
        NSMutableArray *candidateMatches = [NSMutableArray arrayWithArray:objects];
        [weakSelf attemptToJoinMatchAsRandomOpponent:candidateMatches];
      }
    }];
  }];
}

- (void)showWaitingForRandomOpponentAlert {
  [self showNoticeAlertWithCaption:@"Searching for a random opponent. When we find one, you will see a match challenge from a random player."];
}

- (void)makeMatchWaitingForRandomOpponent {
  DLog(@"no available matches waiting for random opponent; creating one.");

  __weak id weakSelf = self;

  [Match matchWithRandomOpponentCompletion:^(BOOL succeeded, NSError *error) {
    [weakSelf hideActivityHUD];

    if (!succeeded) {
      [error showParseError:NSLocalizedString(@"wait for opponent", nil)];
    } else {
      DLog(@"created random match waiting for opponent");
      [weakSelf showWaitingForRandomOpponentAlert];
    }
  }];
}

- (void)clearWaitingRandomMatch {
  PFQuery *query = [PFQuery queryWithClassName:@"Match"];
  [query whereKey:@"state" equalTo:[NSNumber numberWithInt:kMatchStatePending]];
  [query whereKeyExists:@"setupRandom"];
  [query whereKey:@"secondPlayer" equalTo:[PFUser currentUser]];
  [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    if (error) {
      DLog(@"failed to find waiting random match(es): %@", [error localizedDescription]);
    } else {
      for (PFObject *obj in objects)
        [obj deleteEventually];
    }
  }];
}

- (void)attemptToJoinMatchAsRandomOpponent:(NSMutableArray *)candidateMatches {
  if (candidateMatches.count == 0) {
    DLog(@"no further candidate matches to attempt to join");
    [self makeMatchWaitingForRandomOpponent];
    return;
  }

  PFObject *candidateMatch = [candidateMatches objectAtIndex:0];
  [candidateMatches removeObjectAtIndex:0];

  DLog(@"trying to join candidate random match vs user with objectId %@",
       [[candidateMatch objectForKey:@"secondPlayer"] objectId]);

  __weak id weakSelf = self;

  [candidateMatch addUniqueObject:[PFUser currentUser].objectId forKey:@"suitors"];
  [candidateMatch saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (!succeeded) {
      DLog(@"failed to save current user as suitor of match: %@", [error localizedDescription]);
      [weakSelf attemptToJoinMatchAsRandomOpponent:candidateMatches];  // try another maybe
    } else {
      DLog(@"added current user as suitor; checking to see if we won the race to be the first");
      [weakSelf checkIfWonSuitorRace:candidateMatch candidates:candidateMatches];
    }
  }];
}

- (void)checkIfWonSuitorRace:(PFObject *)candidateMatch candidates:(NSMutableArray *)candidates {
  __weak id weakSelf = self;

  PFQuery *query = [PFQuery queryWithClassName:@"Match"];

  [query getObjectInBackgroundWithId:candidateMatch.objectId block:^(PFObject *object, NSError *error) {
    FindOpponentViewController *vc = weakSelf;

    BOOL isFirstSuitor = NO;

    if (error) {
      DLog(@"failed to check if we're the first suitor: %@", [error localizedDescription]);
      // fall through to try other candidates...
    } else {
      NSArray *suitors = [object objectForKey:@"suitors"];
      if (suitors.count > 0) {
        NSString *firstSuitor = [suitors objectAtIndex:0];
        DLog(@"current user = %@; first suitor = %@", [PFUser currentUser].objectId, firstSuitor);
        isFirstSuitor = [firstSuitor isEqualToString:[PFUser currentUser].objectId];
      }
    }

    if (!isFirstSuitor) {
      DLog(@"not first suitor; continuing to check candidate matches");
      [vc attemptToJoinMatchAsRandomOpponent:candidates];  // try another maybe
    } else {
      DLog(@"is first suitor; adding this user as first player and starting match");

      [candidateMatch setObject:[PFUser currentUser] forKey:@"firstPlayer"];
      [candidateMatch removeObjectForKey:@"setupRandom"];
      [candidateMatch removeObjectForKey:@"suitors"];
      [candidateMatch saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!succeeded) {
          DLog(@"failed to save current user as first player of match: %@", [error localizedDescription]);
        } else {
          DLog(@"saved current user as first player in match; showing VC...");

          [vc clearWaitingRandomMatch];

          [vc hideActivityHUD];
          Match *aMatch = [Match matchWithExistingMatchObject:candidateMatch block:nil];
          [vc.navigationController pushViewController:[MatchViewController controllerWithMatch:aMatch] animated:NO];
        }
      }];
    }
  }];
}

#pragma mark - facebook

- (void)doFacebook:(id)sender {
  if (!REQUIRE_USER)
    return;

  [TestFlight passCheckpoint:@"findByFacebook"];

  __weak id weakSelf = self;

  self.selectorMode = kSelectorModeFacebook;

  if ([PFFacebookUtils isLinkedWithUser:[PFUser currentUser]]) {
    DLog(@"current user is linked with fb");

    [self showActivityHUD];
    [self _fetchFacebookFriends];
  } else {
    DLog(@"trying to link with fb ...");

    [PFFacebookUtils
     linkUser:[PFUser currentUser]
     permissions:nil
     block:^(BOOL succeeded, NSError *error) {
       if (error) {
         [error showParseError:NSLocalizedString(@"link accounts", nil)];
         [weakSelf setSelectorMode:kSelectorModeNone];
         [weakSelf hideActivityHUD];
         return;
       }

       [TestFlight passCheckpoint:@"linkWithFacebook"];

       // Fetch Facebook ID of the linked account.
       // Calls -request:didLoad: or -request:didFailWithError:

       [weakSelf showActivityHUD];
       facebookIdRequest = [[PFFacebookUtils facebook] requestWithGraphPath:@"me?fields=id" andDelegate:self];
     }];
  }
}

- (void)_fetchFacebookFriends {
  DLog(@"fetching fb friends ...");

  facebookFriendsRequest = [[PFFacebookUtils facebook] requestWithGraphPath:@"me/friends" andDelegate:self];
}

- (void)_didReceiveFacebookUserID:(id)result {
  // Store the current user's Facebook ID on the user so that we can query for it.

  __weak id weakSelf = self;

  [self startTimeoutTimer];

  [[PFUser currentUser] setObject:[result objectForKey:@"id"] forKey:@"fbId"];
  [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    [weakSelf removeTimeoutTimer];

    if (!succeeded) {
      [weakSelf hideActivityHUD];
      [error showParseError:NSLocalizedString(@"link accounts", nil)];
      self.selectorMode = kSelectorModeNone;
      return;
    }

    DLog(@"stored fbId to parse");

    facebookIdRequest = nil;

    [self _fetchFacebookFriends];
  }];
}

- (void)_didReceiveFacebookFriends:(id)result {
  DLog(@"fetched fb friends ...");

  // Create a list of fb IDs for all the friends of the current user.

  allFacebookFriends = [result objectForKey:@"data"];

  if (allFacebookFriends.count == 0) {
    // No friends (loser!)

    [self hideActivityHUD];
    usersWithAppInstalledFromFacebook = nil;
    return;
  }

  NSMutableArray *facebookFriendIDs = [NSMutableArray arrayWithCapacity:allFacebookFriends.count];
  for (NSDictionary *facebookFriend in allFacebookFriends)
    [facebookFriendIDs addObject:[facebookFriend objectForKey:@"id"]];

  // Query Parse users that have a Facebook ID equal to one of the current user's Facebook friends.
  // These are the app users that already have the app installed.

  DLog(@"cross-referencing Parse for %d fb friends ...", facebookFriendIDs.count);

  __weak id weakSelf = self;

  [self startTimeoutTimer];

  PFQuery *query = [PFUser query];
  [query whereKey:@"fbId" containedIn:facebookFriendIDs];
  [query findObjectsInBackgroundWithBlock:^(NSArray *friendsWithApp, NSError *error) {
    [self removeTimeoutTimer];

    FindOpponentViewController *strongSelf = weakSelf;

    if (error) {
      [weakSelf hideActivityHUD];
      [error showParseError:NSLocalizedString(@"link accounts", nil)];
      strongSelf.selectorMode = kSelectorModeNone;
      return;
    }

    DLog(@"facebook friends: %d; facebook friends using the app: %d",
         facebookFriendIDs.count, friendsWithApp.count);

    if (friendsWithApp.count == 0) {
      strongSelf->usersWithAppInstalledFromFacebook = nil;
      [strongSelf showNoFacebookFriendsAlert];
    } else {
      strongSelf->usersWithAppInstalledFromFacebook = friendsWithApp;
      strongSelf.selectorMode = kSelectorModeFacebook;
      [strongSelf showFacebookUserSelector];
    }
  }];
}

- (void)showNoFacebookFriendsAlert {
  usersWithAppInstalledFromFacebook = nil;

  NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];

  NSString *fmt = NSLocalizedString(@"None of your %@ friends are playing %@. Invite them to join in the fun!",
                                    @"first %@ is social network; second %@ is the app name");

  NSString *message = [NSString stringWithFormat:fmt, @"Facebook", appName];

  __weak id weakSelf = self;

  [self showActionableAlertWithCaption:message
                                 block:^(int buttonPressed) {
                                   if (buttonPressed == 0) { // Cancel
                                     [weakSelf setSelectorMode:kSelectorModeNone];
                                     return;
                                   }
                                   [weakSelf setSelectorMode:kSelectorModeFacebook];
                                   [weakSelf showFacebookUserSelector];
                                 }];
}

- (void)request:(PF_FBRequest *)request didLoad:(id)result {
  DLog(@"fb request finished");

  if (request == facebookIdRequest) {
    [self _didReceiveFacebookUserID:result];
  } else if (request == facebookFriendsRequest) {
    [self _didReceiveFacebookFriends:result];
  }
}

- (void)request:(PF_FBRequest *)request didFailWithError:(NSError *)error {
  DLog(@"fb request failed: %@", [error localizedDescription]);

  [self hideActivityHUD];

  if (request == facebookIdRequest) {
    [error showParseError:NSLocalizedString(@"fetch account info", nil)];
  } else if (request == facebookFriendsRequest) {
    [error showParseError:NSLocalizedString(@"fetch your Facebook friends", nil)];
  }

  facebookIdRequest = facebookFriendsRequest = nil;
}

- (void)showFacebookUserSelector {
  NSMutableArray *friendItems = [NSMutableArray arrayWithCapacity:allFacebookFriends.count];

  NSString *detailTextWithApp = NSLocalizedString(@"Tap to challenge!", nil);
  NSString *detailTextWithoutApp = NSLocalizedString(@"Tap to invite!", nil);

  for (NSDictionary *dict in allFacebookFriends) {
    NSString *fbId = [dict objectForKey:@"id"];

    PFUser *userWithAppInstalled = nil;
    for (PFUser *userWithApp in usersWithAppInstalledFromFacebook) {
      if ([[userWithApp objectForKey:@"fbId"] isEqualToString:fbId]) {
        userWithAppInstalled = userWithApp;
        break;
      }
    }

    NSString *imageURL = [NSString stringWithFormat:@"http://graph.facebook.com/%@/picture?type=square", fbId];
    KNSelectorItem *item = [[KNSelectorItem alloc]
                            initWithDisplayValue:[dict objectForKey:@"name"]
                            selectValue:fbId
                            detailValue:userWithAppInstalled ? detailTextWithApp : detailTextWithoutApp
                            imageUrl:imageURL];

    [friendItems addObject:item];
  }

  NSString *selectText = NSLocalizedString(@"Challenge", nil);
  NSString *inviteText = NSLocalizedString(@"Invite a Friend", nil);

  NSString *selectorTitle = usersWithAppInstalledFromFacebook == 0 ? inviteText : selectText;

  KNMultiItemSelector *selector = [[KNMultiItemSelector alloc]
                                   initWithItems:friendItems
                                   preselectedItems:nil
                                   title:selectorTitle
                                   placeholderText:NSLocalizedString(@"Search by name", nil)
                                   delegate:self];

  selector.allowSearchControl = YES;
  selector.useTableIndex = YES;
  selector.useRecentItems = (usersWithAppInstalledFromFacebook > 0);
  selector.maxNumberOfRecentItems = 4;
  selector.allowModeButtons = NO;

  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selector];
  navController.modalPresentationStyle = UIModalPresentationFormSheet;
  [self presentModalViewController:navController animated:YES];
}

- (void)dialogDidComplete:(PF_FBDialog *)dialog {
  DLog(@"%@", NSStringFromSelector(_cmd));

  [self hideActivityHUD];

  [self dismissModalViewControllerAnimated:YES];
}

- (void)dialogCompleteWithUrl:(NSURL *)url {
  DLog(@"%@: %@", NSStringFromSelector(_cmd), [url absoluteString]);

  [self hideActivityHUD];

  ATMHud *resultHud = [ATMHud new];
  [resultHud setCaption:NSLocalizedString(@"Invited!", nil)];
  [self.view addSubview:resultHud.view];
  [resultHud show];
  [resultHud hideAfter:2];

  [self dismissModalViewControllerAnimated:YES];
}

- (void)dialogDidNotCompleteWithUrl:(NSURL *)url {
  DLog(@"%@: %@", NSStringFromSelector(_cmd), [url absoluteString]);

  [self hideActivityHUD];

  [self dismissModalViewControllerAnimated:YES];
}

- (void)dialogDidNotComplete:(PF_FBDialog *)dialog {
  DLog(@"%@", NSStringFromSelector(_cmd));

  [self hideActivityHUD];

  [self dismissModalViewControllerAnimated:YES];
}

- (void)dialog:(PF_FBDialog*)dialog didFailWithError:(NSError *)error {
  DLog(@"%@: %@", NSStringFromSelector(_cmd), [error localizedDescription]);

  [self hideActivityHUD];

  [self dismissModalViewControllerAnimated:YES];
}

- (void)didSelectFacebookFriend:(KNSelectorItem *)selectedItem {
  [self hideActivityHUD];

  DLog(@"picked FB friend: %@", selectedItem.displayValue);

  NSString *fbId = selectedItem.selectValue;
  for (PFUser *userWithApp in usersWithAppInstalledFromFacebook) {
    if ([[userWithApp objectForKey:@"fbId"] isEqualToString:fbId]) {
      DLog(@"user has app installed; issue challenge (user obj id %@)", userWithApp.objectId);
      [self dismissModalViewControllerAnimated:NO];
      [self startMatchWithUser:userWithApp];
      return;
    }
  }

  DLog(@"user doesn't have app installed .. invite on fb to=%@", fbId);

  NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
  NSString *fmt = NSLocalizedString(@"I want to play you in %@ for iOS.", @"%@ is the app name");
  NSString *message = [NSString stringWithFormat:fmt, appName];
  NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:message, @"message", fbId, @"to", nil];
  [[PFFacebookUtils facebook] dialog:@"apprequests" andParams:params andDelegate:self];
}

#pragma mark - search by username

- (void)doUsername:(id)sender {
  if (!REQUIRE_USER)
    return;

  __weak id weakSelf = self;

  [TestFlight passCheckpoint:@"findByUsername"];

  // Just prompt for a username and start a match with that user... no such user? oh well.
  // You don't want to disclose a way to search for usernames directly... privacy concerns.

  PromptViewController *vc = [PromptViewController controllerWithPrompt:@"Enter your friend's username (exactly)" placeholder:@"Username" callback:^(NSString *text) {
    FindOpponentViewController *strongSelf = weakSelf;

    NSString *searchString = [text trimWhitespace];
    DLog(@"find by username: entered: %@", searchString);

    if ([searchString isEqualToString:[PFUser currentUser].username]) {
      [strongSelf.navigationController popViewControllerAnimated:NO];
      [strongSelf showNoticeAlertWithCaption:@"You cannot create a match with yourself! 😜"];
      return;
    }

    if (searchString.length == 0 ||
        [searchString isEqualToString:[[PFUser currentUser] objectForKey:@"displayName"]]) {
      [strongSelf.navigationController popViewControllerAnimated:NO];
      return;
    }

    [strongSelf.navigationController popViewControllerAnimated:NO];

    DLog(@"find by username: searching...");

    [weakSelf showActivityHUD];

    PFQuery *usernameQuery = [PFUser query];
    [usernameQuery whereKey:@"username" equalTo:[searchString lowercaseString]];

    PFQuery *displayNameQuery = [PFUser query];
    [displayNameQuery whereKey:@"displayName" equalTo:searchString];

    PFQuery *query = [PFQuery orQueryWithSubqueries:[NSArray arrayWithObjects:usernameQuery, displayNameQuery, nil]];

    [self startTimeoutTimer];

    [query findObjectsInBackgroundWithBlock:^(NSArray *users, NSError *error) {
      [weakSelf removeTimeoutTimer];
      [strongSelf hideActivityHUD];
      
      if (error) {
        [error showParseError:NSLocalizedString(@"search", nil)];
        return;
      }

      // To not give away too much information about users, do NOT show a list
      // of matching usernames to pick from.  Just take the first resulting user
      // that is not the local user.

      NSArray *usersNotMe = [users select:^BOOL(PFUser *aUser) {
        return ![[aUser objectId] isEqualToString:[[PFUser currentUser] objectId]];
      }];

      DLog(@"found %d user(s) from username search", usersNotMe.count);

      if (usersNotMe.count == 0) {
        [self showNoticeAlertWithCaption:@"Sorry, no user was found."];
      } else {
        PFUser *matchingUser = [usersNotMe objectAtIndex:0];

        int index = 0;
        while (index < users.count && [[[users objectAtIndex:index] objectId] isEqualToString:[PFUser currentUser].objectId])
          ++index;

        DLog(@"taking matching user: %@", matchingUser.username);
        [strongSelf startMatchWithUser:matchingUser];
      }
    }];
  }];

  [self.navigationController pushViewController:vc animated:NO];
}

#pragma mark - rematch

- (void)doRematch:(id)sender {
  if (!REQUIRE_USER)
    return;

  NSArray *previousOpponentObjectIDs = [[PFUser currentUser] objectForKey:@"opponents"];

  if (previousOpponentObjectIDs.count == 0) {
    [self showNoticeAlertWithCaption:@"No matches played yet!"];
    return;
  }
  
  __weak id weakSelf = self;

  [self showActivityHUD];

  [TestFlight passCheckpoint:@"findByRematch"];

  [self startTimeoutTimer];

  PFQuery *userQuery = [PFUser query];
  [userQuery whereKey:@"objectId" containedIn:previousOpponentObjectIDs];
  [userQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    [weakSelf removeTimeoutTimer];

    if (error) {
      [weakSelf hideActivityHUD];
      [error showParseError:NSLocalizedString(@"search", nil)];
      return;
    }

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:objects.count];

    for (PFUser *user in objects) {
      KNSelectorItem *item = [[KNSelectorItem alloc]
                              initWithDisplayValue:[user usernameForDisplay]
                              selectValue:user.objectId
                              detailValue:nil
                              imageUrl:nil];

      [items addObject:item];
    }

    KNMultiItemSelector *selector = [[KNMultiItemSelector alloc]
                                     initWithItems:items
                                     preselectedItems:nil
                                     title:NSLocalizedString(@"Rematch", nil)
                                     placeholderText:NSLocalizedString(@"Search by name", nil)
                                     delegate:weakSelf];

    selector.allowSearchControl = YES;
    selector.useTableIndex = YES;
    selector.useRecentItems = NO;
    selector.allowModeButtons = NO;

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selector];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [weakSelf presentModalViewController:navController animated:YES];

    [weakSelf setSelectorMode:kSelectorModeRematch];
  }];
}

- (void)didSelectUserForRematch:(KNSelectorItem *)selectedItem {
  DLog(@"picked a user for rematch: %@ (%@)", selectedItem.displayValue, selectedItem.selectValue);
  [self dismissModalViewControllerAnimated:NO];
  self.selectorMode = kSelectorModeNone;
  [self startMatchWithUserID:selectedItem.selectValue];
}

#pragma mark - contacts

- (void)doContacts:(id)sender {
  if (!REQUIRE_USER)
    return;

  __weak id weakSelf = self;

  [TestFlight passCheckpoint:@"findByContacts"];

  // Use an alert in iOS 5.x (not in iOS 6 since that's built-in) to avoid PR fiasco (hi Path! [Feb 2012]).

  NSString *currOsVersion = [[UIDevice currentDevice] systemVersion];
  BOOL preiOS6 = [currOsVersion compare:@"6.0" options:NSNumericSearch] == NSOrderedAscending;

  if (preiOS6) {
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"To find your friends, %@ needs to send your contacts to our server.", @"%@ is the app name"), appName];

    [self showActionableAlertWithCaption:message
                                   block:^(int buttonPressed) {
                                     if (buttonPressed == 0) { // Don't Allow
                                       [weakSelf setSelectorMode:kSelectorModeNone];
                                       return;
                                     }
                                     [weakSelf continueScanningContacts];
                                   }];
  } else {
    // In iOS6 the system prompts the user if it's OK to allow us to access their contacts.
    // If not, we get back no contacts. Fine.
    // One can also set the info.plist key NSContactsUsageDescription to a reason for needing the contacts.
    // but I think that's pretty obvious.

    [self continueScanningContacts];
  }
}

- (void)continueScanningContacts {

  // Get all contacts from the local address book.
  // Search the Parse users for those with an email address matching one of the contacts.
  // Show a user picker for all contacts with one entry per email address (Name - (email)).
  // Let the user pick one and either challenge or invite (via email).

  NSArray *allContacts = [ABContactsHelper contacts];

  NSMutableDictionary *nameForEmail = [NSMutableDictionary dictionaryWithCapacity:allContacts.count];
  for (ABContact *contact in allContacts) {
    if (contact.isPerson) {
      for (NSString *email in contact.emailArray) {
        [nameForEmail setObject:contact.contactName forKey:email];
      }
    }
  }

  DLog(@"found %d contacts with an email address.", allContacts.count);

  if (nameForEmail.count == 0) {
    [self showNoticeAlertWithCaption:@"No contacts in address book"];
    self.selectorMode = kSelectorModeNone;
    return;
  }

  [self showActivityHUD];

  self.selectorMode = kSelectorModeContacts;

  __weak id weakSelf = self;

  [self startTimeoutTimer];

  PFQuery *query = [PFUser query];
  [query whereKey:@"email" containedIn:[nameForEmail allKeys]];
  [query findObjectsInBackgroundWithBlock:^(NSArray *usersWithAppInstalledFromContacts, NSError *error) {
    [weakSelf removeTimeoutTimer];

    if (error) {
      [weakSelf hideActivityHUD];
      [error showParseError:NSLocalizedString(@"query users", nil)];
      return;
    }

    DLog(@"found %d users from contacts (email) with the app installed", usersWithAppInstalledFromContacts.count);

    if (usersWithAppInstalledFromContacts.count == 0) {
      [weakSelf hideActivityHUD];

      NSString *fmt = NSLocalizedString(@"None of your contacts are playing %@. Invite them to join in the fun!", @"%@ is the app name");
      NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
      NSString *message = [NSString stringWithFormat:fmt, appName];

      [self showActionableAlertWithCaption:message
                                     block:^(int buttonPressed) {
                                       if (buttonPressed == 0) { // Cancel
                                         [weakSelf setSelectorMode:kSelectorModeNone];
                                         return;
                                       }
                                       
                                       [weakSelf showContactsSelectorAllContacts:allContacts
                                                                    usersWithApp:usersWithAppInstalledFromContacts];
                                     }];
    } else {
      [weakSelf showContactsSelectorAllContacts:allContacts
                                   usersWithApp:usersWithAppInstalledFromContacts];
    }
  }];
}

- (void)showContactsSelectorAllContacts:(NSArray *)allContacts usersWithApp:(NSArray *)usersWithApp {
  NSMutableArray *items = [NSMutableArray arrayWithCapacity:allContacts.count];

  for (ABContact *contact in allContacts) {
    for (NSString *email in contact.emailArray) {
      PFUser *userWithAppInstalled = nil;

      for (PFUser *user in usersWithApp) {
        if ([user.email isEqualToString:email]) {
          userWithAppInstalled = user;
          break;
        }
      }

      KNSelectorItem *item = [[KNSelectorItem alloc]
                              initWithDisplayValue:contact.contactName
                              selectValue:userWithAppInstalled.objectId // OK if null
                              detailValue:email
                              imageUrl:nil];

      [items addObject:item];
    }
  }

  NSString *selectText = NSLocalizedString(@"Challenge", nil);
  NSString *inviteText = NSLocalizedString(@"Invite a Friend", nil);

  NSString *selectorTitle = usersWithApp.count == 0 ? inviteText : selectText;

  KNMultiItemSelector *selector = [[KNMultiItemSelector alloc]
                                   initWithItems:items
                                   preselectedItems:nil
                                   title:selectorTitle
                                   placeholderText:NSLocalizedString(@"Search by name", nil)
                                   delegate:self];

  selector.allowSearchControl = YES;
  selector.useTableIndex = YES;
  selector.useRecentItems = (usersWithApp.count > 0);
  selector.maxNumberOfRecentItems = 4;
  selector.allowModeButtons = NO;

  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selector];
  navController.modalPresentationStyle = UIModalPresentationFormSheet;
  [self presentModalViewController:navController animated:YES];

  self.selectorMode = kSelectorModeContacts;
}

- (void)didSelectContact:(KNSelectorItem *)selectedItem {
  DLog(@"picked a contact: %@ (%@)", selectedItem.displayValue, selectedItem.selectValue);

  self.selectorMode = kSelectorModeNone;
  [self dismissModalViewControllerAnimated:NO];

  NSString *parseUserObjectID = selectedItem.selectValue;

  if (parseUserObjectID) {
    DLog(@"picked contact has app installed... start match!");

    [self startMatchWithUserID:selectedItem.selectValue];
  } else {
    DLog(@"picked contact does not have app installed... invite via email.");

    [self inviteViaEmail:selectedItem.detailValue];
    [self hideActivityHUD];
  }
}

#pragma mark - invite via email

- (void)inviteViaEmail:(NSString *)email {
  [TestFlight passCheckpoint:@"inviteByEmail"];

  if ([MFMailComposeViewController canSendMail]) {
    MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
    mailVC.mailComposeDelegate = self;

    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    [mailVC setSubject:appName];

    [mailVC setToRecipients:[NSArray arrayWithObject:email]];

    NSString *message = NSLocalizedString(@"I want to play you in <b>%@</b> for iOS.", @"%@ is the app name");
    NSString *getIt = NSLocalizedString(@"Get it <a href=\"%@\">here</a> on the App Store!", nil);
    NSString *fmt = [[message stringByAppendingString:@" "] stringByAppendingString:getIt];
    NSString *body = [NSString stringWithFormat:fmt, appName, kAppStorePublicURL];
    [mailVC setMessageBody:body isHTML:YES];

    [self.navigationController presentModalViewController:mailVC animated:YES];
  } else {
    [self showNoticeAlertWithCaption:@"Cannot send email. Try later"];
  }
}

#pragma mark - pass and play

- (void)doPassAndPlay:(id)sender {
  // NB: of course, no simultaneous match check here.

  [TestFlight passCheckpoint:@"findByPassAndPlay"];

  Match *match = [Match resumablePassAndPlayMatch];

  if (!match) {
    PFUser *player1 = [PFUser user];
    player1.username = NSLocalizedString(@"Player1", @"Name of first player for pass-and-play matches");

    PFUser *player2 = [PFUser user];
    player2.username = NSLocalizedString(@"Player2", @"Name of first player for pass-and-play matches");

    match = [[Match alloc] initWithPlayer:player1 player:player2];
    match.passAndPlay = YES;
  }

  MatchViewController *vc = [MatchViewController controllerWithMatch:match];
  [self.navigationController pushViewController:vc animated:NO];
}

#pragma mark - twitter

- (void)doTweetInvite:(id)sender {
  if ([TWTweetComposeViewController canSendTweet]) {
    TWTweetComposeViewController *vc = [[TWTweetComposeViewController alloc] init];

    NSString *fmt = NSLocalizedString(@"Let's play %@! My username is \"%@\". #Lexatron",
                                      @"Tweet about the app (first %@ is app name; second %@ is username");

    NSString *displayName = [[PFUser currentUser] usernameForDisplay];

    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    [vc setInitialText:[NSString stringWithFormat:fmt, appName, displayName]];

    [self.navigationController presentViewController:vc animated:YES completion:nil];
  }
}


#pragma mark - match

// NB: not a pass-and-play match here.

- (void)startMatchWithUser:(PFUser *)targetUser {
  __weak id weakSelf = self;

  [self showActivityHUD];

  [self startTimeoutTimer];

  [[PFUser currentUser] countOfActiveMatches:^(int number, NSError *error) {
    [weakSelf removeTimeoutTimer];
    [weakSelf hideActivityHUD];

    if (error) {
      [error showParseError:@"communicate with server"];
      return;
    }

    DLog(@"user has %d active matches; limit is %d", number, kMaxSimultaneousMatches);

    if (number >= kMaxSimultaneousMatches) {
      [self showNoticeAlertWithCaption:@"We're glad you love this game! However, you have reached the limit on simultaneous matches. Too many simultaneous matches will overburden our servers. Please complete one of your existing matches and try again. We hope you understand."];
      return;
    }

    [weakSelf clearWaitingRandomMatch];  // if any

    DLog(@"starting a new match between current local user: %@ (%@) and user: %@ (%@)",
         [[PFUser currentUser] usernameForDisplay],
         [PFUser currentUser].objectId,
         [targetUser usernameForDisplay],
         targetUser.objectId);

    // Create a match and show match VC so that the first player (local user) can play the first turn.
    // It's a bit roundabout but the Match object is set on the VC in -prepareForSegue.
    // Storyboards are a bit weird like that.

    Match *match = [[Match alloc] initWithPlayer:[PFUser currentUser] player:targetUser];
    MatchViewController *vc = [MatchViewController controllerWithMatch:match];
    [[weakSelf navigationController] pushViewController:vc animated:NO];
  }];
}

// Fetch user object from ID then continue.

- (void)startMatchWithUserID:(NSString *)userID {
  __weak id weakSelf = self;

  [self startTimeoutTimer];

  PFQuery *query = [PFUser query];
  [query whereKey:@"objectId" equalTo:userID];
  [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    [weakSelf removeTimeoutTimer];
    
    if (error) {
      [weakSelf hideActivityHUD];
      [error showParseError:NSLocalizedString(@"search", nil)];
    } else {
      [weakSelf startMatchWithUser:[objects objectAtIndex:0]];
    }
  }];
}

#pragma mark - MultiItemSelectorDelegate

- (void)selectorDidCancelSelection {
  self.selectorMode = kSelectorModeNone;
  [self hideActivityHUD];
  [self dismissModalViewControllerAnimated:YES];
}

- (void)selectorDidSelectItem:(KNSelectorItem*)selectedItem {
  switch (_selectorMode) {
    case kSelectorModeNone:
      NSAssert(NO, @"selectorMode must be set");
      break;

    case kSelectorModeContacts:
      [self didSelectContact:selectedItem];
      break;
      
    case kSelectorModeFacebook:
      [self didSelectFacebookFriend:selectedItem];
      break;
      
    case kSelectorModeRematch:
      [self didSelectUserForRematch:selectedItem];
      break;
  }
  
  self.selectorMode = kSelectorModeNone;
}

- (void)selectorDidFinishSelectionWithItems:(NSArray *)selectedItems {
  // Only called when we allow multiple selections by not closing in didSelectItem:
  // which we don't currently do so this is never called
  
  self.selectorMode = kSelectorModeNone;
  [self hideActivityHUD];
  [self dismissModalViewControllerAnimated:YES];
}

@end
