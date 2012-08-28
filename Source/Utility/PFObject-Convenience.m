#import "PFObject-Convenience.h"

@implementation PFObject (Convenience)

- (void)setInt:(int)n forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithInt:n] forKey:key];
}

- (int)intForKey:(NSString *)key {
  return [[self objectForKey:key] intValue];
}

- (void)setBool:(BOOL)b forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithBool:b] forKey:key];
}

- (BOOL)boolForKey:(NSString *)key {
  return [[self objectForKey:key] boolValue];
}

- (void)setFloat:(float)f forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithFloat:f] forKey:key];
}

- (float)floatForKey:(NSString *)key {
  return [[self objectForKey:key] floatValue];
}

@end