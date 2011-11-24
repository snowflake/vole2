//
//  CheckVienna.m
//  Vienna
//
//  Created by David Evans on 24/11/2011.
//  Copyright 2011 David Evans. All rights reserved.
//

#import "CheckVienna.h"


@implementation CheckVienna
-(void)awakeFromNib {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Cannot start this application. Another instance of Vienna is running."];
	[alert setInformativeText:@"Please quit from the other Vienna application and try again."];
	[alert runModal ];
	exit(0);
}
@end
