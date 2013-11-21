//
//  MessageInfoBar.m
//  Vienna
//
//  Created by Steve on Fri Apr 23 2004.
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

#import "MessageInfoBar.h"
#import "CalendarExtensions.h"
#import "Database.h"

@implementation MessageInfoBar

/* drawRect
 * Paint the view background in white and draw a dark grey border at the top
 * to separate it from the splitter.
 */
-(void)drawRect:(NSRect)rect
{
	[[NSColor whiteColor] set];
	[NSBezierPath fillRect:rect];
	
	NSBezierPath * bpath = [NSBezierPath bezierPath];
	NSRect viewRect = [self bounds];
	[[NSColor darkGrayColor] set];
	[bpath setLineWidth:1.0];
	[bpath moveToPoint:NSMakePoint(viewRect.origin.x, viewRect.origin.y)];
	[bpath lineToPoint:NSMakePoint(viewRect.origin.x, (viewRect.origin.y + viewRect.size.height) - 1)];
	[bpath lineToPoint:NSMakePoint(viewRect.size.width + viewRect.origin.x, (viewRect.origin.y + viewRect.size.height) - 1)];
	[bpath stroke];
}

/* update
 * Updates the info bar using the specified message. If message is nil then the
 * bar shows "No message selected".
 */
-(void)update:(VMessage *)message database:(Database *)db
{
	NSAssert(db != nil, @"database parameter cannot be nil");
	if (message == nil)
		[infoBarText setStringValue:@""];
	else
	{
		NSFont * normalFont = [NSFont fontWithName:@"Helvetica" size:12];
		NSFont * boldFont = [[NSFontManager sharedFontManager] convertFont:normalFont toHaveTrait:NSBoldFontMask];
		NSDictionary * normalDict = [NSDictionary dictionaryWithObject:normalFont forKey:NSFontAttributeName];
		NSDictionary * boldDict = [NSDictionary dictionaryWithObject:boldFont forKey:NSFontAttributeName];

		NSMutableAttributedString * infoBarString = [[NSMutableAttributedString alloc] init];

#warning 64BIT: Check formatting arguments
		NSString * messageNumber = [NSString stringWithFormat:@"%d", [message messageId]];
		NSString * senderName = [message sender];
		NSString * messageDate = [[[message date] dateWithCalendarFormat:nil timeZone:nil] friendlyDescription];
		NSString * folderName = [db folderPathName:[message folderId]];
		
		NSAttributedString * msgLabel = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Message ", nil) attributes:normalDict];
		NSAttributedString * numberPart = [[NSAttributedString alloc] initWithString:messageNumber attributes:boldDict];
		NSAttributedString * inLabel = [[NSAttributedString alloc] initWithString:NSLocalizedString(@" in ", nil) attributes:normalDict];
		NSAttributedString * folderNamePart = [[NSAttributedString alloc] initWithString:folderName attributes:boldDict];
		NSAttributedString * fromLabel = [[NSAttributedString alloc] initWithString:NSLocalizedString(@" from ", nil) attributes:normalDict];
		NSAttributedString * senderNamePart = [[NSAttributedString alloc] initWithString:senderName attributes:boldDict];
		NSAttributedString * postedLabel = [[NSAttributedString alloc] initWithString:NSLocalizedString(@", posted ", nil) attributes:normalDict];
		NSAttributedString * datePart = [[NSAttributedString alloc] initWithString:messageDate attributes:boldDict];
		
		[infoBarString appendAttributedString:msgLabel];
		[infoBarString appendAttributedString:numberPart];
		[infoBarString appendAttributedString:inLabel];
		[infoBarString appendAttributedString:folderNamePart];
		[infoBarString appendAttributedString:fromLabel];
		[infoBarString appendAttributedString:senderNamePart];
		[infoBarString appendAttributedString:postedLabel];
		[infoBarString appendAttributedString:datePart];

		if ([message comment])
		{
#warning 64BIT: Check formatting arguments
			NSString * commentNumber = [NSString stringWithFormat:@"%d", [message comment]];
			NSAttributedString * commentLabel = [[NSAttributedString alloc] initWithString:NSLocalizedString(@". Comment to message ", nil) attributes:normalDict];
			NSAttributedString * commentPart = [[NSAttributedString alloc] initWithString:commentNumber attributes:boldDict];

			[infoBarString appendAttributedString:commentLabel];
			[infoBarString appendAttributedString:commentPart];

			[commentPart release];
			[commentLabel release];
		}
		
		[infoBarText setObjectValue:infoBarString];

		[datePart release];
		[postedLabel release];
		[senderNamePart release];
		[fromLabel release];
		[folderNamePart release];
		[inLabel release];
		[numberPart release];
		[msgLabel release];
		[infoBarString release];
	}
}
@end
