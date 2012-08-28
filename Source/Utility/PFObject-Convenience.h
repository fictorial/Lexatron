@interface PFObject (Convenience)

- (void)setInt:(int)n forKey:(NSString *)key;
- (int)intForKey:(NSString *)key;

- (void)setBool:(BOOL)b forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)setFloat:(float)f forKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;

@end