#import "UIView-GeomHelpers.h"

@implementation UIView (GeomHelpers)

#pragma mark - getters

- (CGFloat)width {
  return self.bounds.size.width;
}

- (CGFloat)height {
  return self.bounds.size.height;
}

- (CGFloat)left {
  return CGRectGetMinX(self.frame);
}

- (CGFloat)top {
  return CGRectGetMinY(self.frame);
}

- (CGFloat)right {
  return CGRectGetMaxX(self.frame);
}

- (CGFloat)bottom {
  return CGRectGetMaxY(self.frame);
}

- (CGPoint)topLeft {
  return CGPointMake(self.left, self.top);
}

- (CGPoint)topRight {
  return CGPointMake(self.right, self.top);
}

- (CGPoint)bottomLeft {
  return CGPointMake(self.left, self.bottom);
}

- (CGPoint)bottomRight {
  return CGPointMake(self.right, self.bottom);
}

- (CGPoint)topMiddle {
  return CGPointMake(self.center.x, self.top);
}

- (CGPoint)bottomMiddle {
  return CGPointMake(self.center.x, self.bottom);
}

- (CGPoint)leftMiddle {
  return CGPointMake(self.left, self.center.y);
}

- (CGPoint)rightMiddle {
  return CGPointMake(self.right, self.center.y);
}

#pragma mark - setters

- (void)setWidth:(CGFloat)width {
  NSAssert(width > 0, @"invalid parameter value");

  CGRect frame = self.frame;
  frame.size.width = width;
  frame.origin.x += width/2;
  self.frame = frame;
}

- (void)setHeight:(CGFloat)height {
  NSAssert(height > 0, @"invalid parameter value");
  
  CGRect frame = self.frame;
  frame.size.width = height;
  frame.origin.y += height/2;
  self.frame = frame;
}

- (void)setLeft:(CGFloat)left {
  CGRect frame = self.frame;
  frame.origin.x = left;
  self.frame = frame;
}

- (void)setTop:(CGFloat)top {
  CGRect frame = self.frame;
  frame.origin.y = top;
  self.frame = frame;
}

- (void)setRight:(CGFloat)right {
  CGRect frame = self.frame;
  frame.origin.x = right - frame.size.width;
  self.frame = frame;
}

- (void)setBottom:(CGFloat)bottom {
  CGRect frame = self.frame;
  frame.origin.y = bottom - frame.size.height;
  self.frame = frame;
}

- (void)setTopLeft:(CGPoint)topLeft {
  self.top = topLeft.y;
  self.left = topLeft.x;
}

- (void)setTopRight:(CGPoint)topRight {
  self.top = topRight.y;
  self.right = topRight.x;
}

- (void)setBottomLeft:(CGPoint)bottomLeft {
  self.left = bottomLeft.x;
  self.bottom = bottomLeft.y;
}

- (void)setBottomRight:(CGPoint)bottomRight {
  self.right = bottomRight.x;
  self.bottom = bottomRight.y;
}

- (void)setTopMiddle:(CGPoint)topMiddle {
  self.center = CGPointMake(topMiddle.x, topMiddle.y + CGRectGetHeight(self.bounds)/2);
}

- (void)setBottomMiddle:(CGPoint)bottomMiddle {
  self.center = CGPointMake(bottomMiddle.x, bottomMiddle.y - CGRectGetHeight(self.bounds)/2);
}

- (void)setLeftMiddle:(CGPoint)leftMiddle {
  self.center = CGPointMake(leftMiddle.x + CGRectGetWidth(self.bounds)/2, leftMiddle.y);
}

- (void)setRightMiddle:(CGPoint)rightMiddle {
  self.center = CGPointMake(rightMiddle.x - CGRectGetWidth(self.bounds)/2, rightMiddle.y);
}

@end