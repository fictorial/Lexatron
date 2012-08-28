#import "UIImage-AppAdditions.h"

@implementation UIImage (AppAdditions)

- (UIImage *)imageAtRect:(CGRect)rect {
  CGFloat scale = [UIScreen mainScreen].scale;
  CGRect scaledRect = CGRectApplyAffineTransform(rect, CGAffineTransformMakeScale(scale, scale));
  CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], scaledRect);
  UIImage *subImage = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  return subImage;
}

+ (UIImage *)imageWithName:(NSString *)name {
  NSString *actualName = name;
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    actualName = [NSString stringWithFormat:@"%@@2x.png", name];
  }
  return [UIImage imageNamed:actualName];
}

@end
