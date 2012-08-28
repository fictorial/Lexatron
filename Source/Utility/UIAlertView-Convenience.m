#import "UIAlertView-Convenience.h"
#import "BaseViewController.h"

@implementation UIAlertView (BridgeToMK)

+ (void) showAlertViewWithTitle: (NSString *) title
                        message: (NSString *) message
              cancelButtonTitle: (NSString *) cancelButtonTitle
              otherButtonTitles: (NSArray *) otherButtonTitles
                        handler: (void (^)(UIAlertView *, NSInteger)) block {

  /*
  BlockAlertView *alert = [[BlockAlertView alloc] initWithTitle:title message:message];
  [alert setCancelButtonWithTitle:cancelButtonTitle block:^{
    block(nil, 0);
  }];

  if (otherButtonTitles.count > 0)
  [alert addButtonWithTitle:[otherButtonTitles objectAtIndex:0] block:^{
    block(nil, 1);
  }];

  [alert show];
   */

  /*
  UIAlertView *alertView;

  alertView = [UIAlertView
               alertViewWithTitle:title
               message:message
               cancelButtonTitle:cancelButtonTitle
               otherButtonTitles:otherButtonTitles
               onDismiss:^(int buttonIndex) { block(alertView, buttonIndex); }
               onCancel:^{ block(alertView, 0); }];

// Seems to perform better when presented this way.
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [alertView show];
  });
   */
}

@end