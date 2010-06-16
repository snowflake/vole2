//
//  Message.m
//  Vienna
//
//  Created by Steve on Thu Feb 19 2004.
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

#import "VMessage.h"

// The names here must correspond to the messageList identifiers
NSString * MA_Column_MessageId = @"headerNumber";
NSString * MA_Column_MessageTitle = @"headerTitle";
NSString * MA_Column_MessageFrom = @"headerFrom";
NSString * MA_Column_MessageDate = @"headerDate";
NSString * MA_Column_MessageComment = @"headerComment";
NSString * MA_Column_MessageUnread = @"headerUnread";
NSString * MA_Column_MessageFlagged = @"headerFlagged";
NSString * MA_Column_MessageText = @"headerText";
NSString * MA_Column_MessageFolderId = @"headerFolder";
NSString * MA_Column_MessagePriority = @"headerPriority";
NSString * MA_Column_MessageIgnored = @"headerIgnored";
NSString * MA_Column_MessageGuid = @"headerGuid";

@implementation VMessage

/* initWithData
 */
-(id)initWithInfo:(int)newMessageId
{
	if ((self = [super init]) != nil)
	{
		messageData = [[NSMutableDictionary dictionary] retain];
		readFlag = NO;
		markedFlag = NO;
		priorityFlag = NO;
		level = 0;
		[self setFolderId:-1];
		[self setNumber:newMessageId];
	}
	return self;
}

/* setTitle
 */
-(void)setTitle:(NSString *)newMessageTitle
{
	[messageData setObject:newMessageTitle forKey:MA_Column_MessageTitle];
}

/* setSender
 */
-(void)setSender:(NSString *)newMessageSender
{
	[messageData setObject:newMessageSender forKey:MA_Column_MessageFrom];
}

/* setGuid
 */
-(void)setGuid:(NSString *)newGuid
{
	[messageData setObject:newGuid forKey:MA_Column_MessageGuid];
}

/* setDateFromDate
 */
-(void)setDateFromDate:(NSDate *)newMessageDate
{
	[messageData setObject:newMessageDate forKey:MA_Column_MessageDate];
}

/* setText
 */
-(void)setText:(NSString *)newText
{
	[messageData setObject:newText forKey:MA_Column_MessageText];
}

/* markRead
 */
-(void)markRead:(BOOL)flag
{
	if (flag) {
		[messageData setObject:[NSImage imageNamed:@"alphaPixel.tiff"] forKey:MA_Column_MessageUnread];
	} else {
		[messageData setObject:[NSImage imageNamed:@"unread.tiff"] forKey:MA_Column_MessageUnread];
	}
	readFlag = flag;
}

/* markFlagged
*/
-(void)markFlagged:(BOOL)flag
{
	if (flag) {
		[messageData setObject:[NSImage imageNamed:@"flagged.tiff"] forKey:MA_Column_MessageFlagged];
	} else {
		[messageData setObject:[NSImage imageNamed:@"alphaPixel.tiff"] forKey:MA_Column_MessageFlagged];
	}
	markedFlag = flag;
}

/* Accessor functions
 */
-(NSDictionary *)messageData	{ return messageData; }
-(BOOL)isRead					{ return readFlag; }
-(BOOL)isFlagged				{ return markedFlag; }
-(BOOL)isPriority				{ return priorityFlag; }
-(int)level						{ return level; }
-(int)folderId					{ return [[messageData objectForKey:MA_Column_MessageFolderId] intValue]; }
-(VMessage *)lastChildMessage	{ return lastChildMessage; }
-(NSString *)sender				{ return [messageData objectForKey:MA_Column_MessageFrom]; }
-(int)messageId					{ return [[messageData objectForKey:MA_Column_MessageId] intValue]; }
-(NSString *)title				{ return [messageData objectForKey:MA_Column_MessageTitle]; }
-(int)comment					{ return [[messageData objectForKey:MA_Column_MessageComment] intValue]; }
-(NSString *)text				{ return [messageData objectForKey:MA_Column_MessageText]; }
-(NSString *)guid				{ return [messageData objectForKey:MA_Column_MessageGuid]; }
-(NSDate *)date					{ return [messageData objectForKey:MA_Column_MessageDate]; }

/* setLevel
 */
-(void)setLevel:(int)n
{
	level = n;
}

/* setFolderId
 */
-(void)setFolderId:(int)newFolderId
{
	[messageData setObject:[NSNumber numberWithInt:newFolderId] forKey:MA_Column_MessageFolderId];
}

/* setLastChildMessage
 */
-(void)setLastChildMessage:(VMessage *)message
{
	lastChildMessage = message;
}

/* setNumber
 */
-(void)setNumber:(int)newMessageId
{
	[messageData setObject:[NSNumber numberWithInt:newMessageId] forKey:MA_Column_MessageId];
}

/* setComment
 */
-(void)setComment:(int)newMessageComment
{
	[messageData setObject:[NSNumber numberWithInt:newMessageComment] forKey:MA_Column_MessageComment];
}

/* markPriority
 */
-(void)markPriority:(BOOL)flag
{
	priorityFlag = flag;
}

/* markIgnored
 */
-(void)markIgnored:(BOOL)flag
{
	ignoredFlag = flag;
}

/* isIgnored
 */
-(BOOL)isIgnored
{
	return ignoredFlag;
}

/* description
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"Message ID %u", [self messageId]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[messageData release];
	[super dealloc];
}
@end
