@interface UIAlertView (BridgeToMK)

// Originally wrote my code against BlocksKit which turned out to cause crashes.
// Switched to UIKitCategoryAdditions for blocks-based UIAlertViews.
// Kept original code as we'll go back to BlocksKit later.

+ (void) showAlertViewWithTitle: (NSString *) title
                        message: (NSString *) message
              cancelButtonTitle: (NSString *) cancelButtonTitle
              otherButtonTitles: (NSArray *) otherButtonTitles
                        handler: (void (^)(UIAlertView *, NSInteger)) block;

@end