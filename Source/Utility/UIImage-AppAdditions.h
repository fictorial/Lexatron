#import <Foundation/Foundation.h>

@interface UIImage (AppAdditions)

// Returns the subimage of the receiver at the given rectangle.

- (UIImage *)imageAtRect:(CGRect)rect;

// imageNamed on iPhones, forces @2x on iPad

+ (UIImage *)imageWithName:(NSString *)name;

@end