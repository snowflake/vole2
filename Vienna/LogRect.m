/*
 *  LogRect.m
 *  Vole
 *
 *  Created by David Evans on 09/10/2012.
 *  Copyright 2012 David Evans. All rights reserved.
 *
 */

/*
 * Log the origin and size of an NSRect */

#import "LogRect.h"

void LogRect(NSString * comment, NSRect rect){
// #warning 64BIT: Check formatting arguments
	NSLog(@"%@:  origin x: %f y: %f, size width: %f height %f",
		  comment, (double)rect.origin.x, (double)rect.origin.y, (double)rect.size.width, (double)rect.size.height);
	
}
