@interface PFUser (AppAdditions)

// We use both username and displayName properties.
//
// The latter is for Facebook users who signup via Facebook login.
// Their usernames are generated strings. We thus generate a 
// displayName based on their full-name. This however cannot be
// made unique (e.g. JohnSmith is common, etc.).
//
// Thus, if we have a displayName, use it. Else use username.

- (NSString *)usernameForDisplay;

// Does the receiver block the given user?

- (BOOL)blocks:(PFUser *)user;

// Be sure to call -saveXXX after calling these:

- (void)block:(PFUser *)user;
- (void)unblock:(PFUser *)user;

- (NSString *)pushChannelName;

// "actionable" => this user is current in a match and can _act_ (play/pass/etc.)

- (void)countOfActionableMatches:(PFIntegerResultBlock)block;
- (void)actionableMatches:(PFArrayResultBlock)block;
- (void)unactionableMatches:(PFArrayResultBlock)block;
- (void)completedMatches:(PFArrayResultBlock)block;

// The current user is either the first or second player but we don't care whose turn it is.
// Useful to set limits on the number of simultaneous matches a player can be a participant of.

- (void)countOfActiveMatches:(PFIntegerResultBlock)block;

@end