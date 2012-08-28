#import "NSObject-PerformBlock.h"

#define TimeDelay(t) dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * t)

@implementation NSObject (PerformBlock)

- (void)performBlock:(PerformBlock)block afterDelay:(NSTimeInterval)delay {
  dispatch_after(TimeDelay(delay), dispatch_get_main_queue(), ^{
    block(self);
  });
}

@end
