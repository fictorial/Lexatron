#import "NSError-AppAdditions.h"
#import "BaseViewController.h"

@implementation NSError (AppAdditions)

- (void)showParseError:(NSString *)actionDescription {
  NSString *errorFmt = NSLocalizedString(@"Failed to %@. Please try again later.\n\n%@",
                                         @"Failed to do something (first %@) because of error (second %@)");
  
  NSString *errorMsg = [NSString stringWithFormat:errorFmt, actionDescription, [self localizedDescription]];

  DLog(@"ERROR: %@", errorMsg);

  UINavigationController *nav = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
  if ([nav.topViewController isKindOfClass:BaseViewController.class]) {
    BaseViewController *baseVC = (BaseViewController *)nav.topViewController;
    [baseVC hideActivityHUD];
    [baseVC showNoticeAlertWithCaption:errorMsg];
  }
}

@end
