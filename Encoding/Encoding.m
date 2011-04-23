#import "Encoding.h"

@implementation Encoding

-(void) awakeFromNib
{
	
	[encoding setStringValue: 
	 [NSString localizedNameOfStringEncoding:
	  [ NSString defaultCStringEncoding ] ] ];
	
}

@end

