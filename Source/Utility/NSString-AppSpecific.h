@interface NSString (AppAdditions)
- (NSString *)trimWhitespace;
- (NSString *)checkValidUsername;  // returns error message or nil if ok
- (NSString *)checkValidPassword;  // same
- (NSString *)checkValidEmail;     // same
@end

