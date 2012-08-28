
@interface NSDictionary (Convenience)

- (int)intForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;

@end

@interface NSMutableDictionary (Convenience)

- (void)setInt:(int)n forKey:(NSString *)key;
- (void)setBool:(BOOL)b forKey:(NSString *)key;
- (void)setFloat:(float)f forKey:(NSString *)key;

@end