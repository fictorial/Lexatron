#import "NSDictionary-Convenience.h"

@implementation NSDictionary (Convenience)

- (int)intForKey:(NSString *)key {
  return [[self objectForKey:key] intValue];
}

- (BOOL)boolForKey:(NSString *)key {
  return [[self objectForKey:key] boolValue];
}

- (float)floatForKey:(NSString *)key {
  return [[self objectForKey:key] floatValue];
}

@end

@implementation NSMutableDictionary (Convenience)

- (void)setInt:(int)n forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithInt:n] forKey:key];
}

- (void)setBool:(BOOL)b forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithBool:b] forKey:key];
}

- (void)setFloat:(float)f forKey:(NSString *)key {
  [self setObject:[NSNumber numberWithFloat:f] forKey:key];
}

@end
