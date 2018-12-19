// Logging functions
// DJE

#if DEBUG
#define _logit() NSLog(@"%@ %@ %@ line %d", NSStringFromClass([self class]), [[NSString stringWithUTF8String:__FILE__] lastPathComponent], NSStringFromSelector(_cmd),__LINE__)

#define _callstack()   NSLog(@"%@ %@ %@ line %d\n%@", NSStringFromClass([self class]), [[NSString stringWithUTF8String:__FILE__] lastPathComponent], NSStringFromSelector(_cmd),__LINE__, [NSThread callStackSymbols])

#define LOGLINE _logit();
#define CALLSTACK _callstack();
#else
// Not debug
#define LOGLINE
#define CALLSTACK
#endif  // DEBUG
  
