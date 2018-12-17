//
//  URLHandlerCommand.m
//  Vienna
//
//  Created by Steve on Wed Feb 04 2004.
//  Copyright (c) 2004 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "URLHandlerCommand.h"
#import "AppController.h"

@implementation ViennaScriptCommand

/* performDefaultImplementation
 * This is the entry point for all link handlers associated with Vienna. Currently we parse
 * and manage the following formats:
 *
 *   cix:<conference/topic>:<messagenumber>
 *   cixfile:<conference/topic>:<filename>
 *   feed://<rss link>
 */
-(id)performDefaultImplementation
{
	NSScanner * scanner = [NSScanner scannerWithString:[self directParameter]];
	NSString * urlPrefix;

	[scanner scanUpToString:@":" intoString:&urlPrefix];
	[scanner scanString:@":" intoString:nil];
	if ([urlPrefix isEqualToString:@"cix"])
	{
		NSString * folderPath = nil;
		int messageNumber = 0;

		// Break apart the CIX URL into the parts we need to handle. Some
		// of these may be missing - this is OK. We'll just try and interpret
		// as much as we can.
		messageNumber = -1;
		[scanner scanUpToString:@":" intoString:&folderPath];
		if ([scanner scanString:@":" intoString:nil])
//#warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
			[scanner scanInt:&messageNumber];
		else
		{
			// #warning 64BIT dje integerValue -> intValue
			if ((messageNumber = [folderPath intValue]) > 0)
				folderPath = nil;
		}

		// Hand off the result to the delegate
		AppController * app = (AppController *)[NSApp delegate];
		[app handleCIXLink:folderPath messageNumber:messageNumber];
	}
	else if ([urlPrefix isEqualToString:@"feed"])
	{
		NSString * feedScheme = nil;

		// Throw away the next few bits if they exist
		[scanner scanString:@"//" intoString:nil];
		[scanner scanString:@"http:" intoString:&feedScheme];
		[scanner scanString:@"https:" intoString:&feedScheme];
		[scanner scanString:@"//" intoString:nil];

		// The rest is the interesting part
		NSString * linkPath;

		[scanner scanUpToString:@"" intoString:&linkPath];
		if (feedScheme == nil)
			feedScheme = @"http:";
		linkPath = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];

		AppController * app = (AppController *)[NSApp delegate];
		[app handleRSSLink:linkPath];
	}
	if ([urlPrefix isEqualToString:@"cixfile"])
	{
		NSString * folderPath = nil;
		NSString * fileName = nil;
		
		// Break apart the CIX URL into the parts we need to handle. Some
		// of these may be missing - this is OK. We'll just try and interpret
		// as much as we can.
		[scanner scanUpToString:@":" intoString:&folderPath];
		[scanner scanString:@":" intoString:nil];
		[scanner scanUpToString:@"" intoString:&fileName];
		
		// Hand off the result to the delegate
		AppController * app = (AppController *)[NSApp delegate];
		[app handleCIXFileLink:folderPath file:fileName];
	}
    return nil;
}
@end
