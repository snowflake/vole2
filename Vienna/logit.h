#define logit() \
  NSLog(@"%@ %@ %@ line %d", NSStringFromClass([self class]), [[NSString stringWithUTF8String:__FILE__] lastPathComponent], NSStringFromSelector(_cmd),__LINE__)
