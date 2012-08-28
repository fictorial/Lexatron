// http://www.cimgf.com/2010/05/02/my-current-prefix-pch-file/


#if DEBUG || ADHOC

#define DLog(...) TFLog(@"<%s> %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#define ALog(...) [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding] file:[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lineNumber:__LINE__ description:__VA_ARGS__]
#define TODO(msg) [[[[UIAlertView alloc] initWithTitle:@"TO DO" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];

#else    // Release, App Store

#define DLog(...) do { } while (0)

#ifndef NS_BLOCK_ASSERTIONS
  #define NS_BLOCK_ASSERTIONS
#endif

#define ALog(...) NSLog(@"ASSERTION FAILED IN %s -- %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])

#define TODO(msg) NSLog(@"TODO: %@", msg)

#endif


#define ZAssert(condition, ...) do { if (!(condition)) { ALog(__VA_ARGS__); }} while(0)