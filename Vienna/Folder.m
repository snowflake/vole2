//
//  Folder.m
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

#import "Folder.h"
#import "AppController.h"

@implementation Folder

/* initWithId
*/
-(id)initWithId:(NSInteger)newId parentId:(NSInteger)newIdParent name:(NSString *)newName permissions:(NSInteger)newPerms
{
	if ((self = [super init]) != nil)
	{
		itemId = newId;
		parentId = newIdParent;
		unreadCount = 0;
		childUnreadCount = 0;
		priorityUnreadCount = 0;
		permissions = newPerms;
		isUnreadCountChanged = NO;
		isMessages = NO;
		hasDescription = NO;
		messages = [[NSMutableDictionary dictionary] retain];
		name = [newName retain];
		description = nil;
		link = nil;
	}
	return self;
}

/* itemId
 * Returns this item's ID.
 */
-(NSInteger)itemId
{
	return itemId;
}

/* parentId
 * Returns this item's parent ID.
 */
-(NSInteger)parentId
{
	return parentId;
}

/* unreadCount
 */
-(NSInteger)unreadCount
{
	return unreadCount;
}

/* permissions
 */
-(NSInteger)permissions
{
	return permissions;
}

/* priorityUnreadCount
 */
-(NSInteger)priorityUnreadCount
{
	return priorityUnreadCount;
}

/* childUnreadCount
 */
-(NSInteger)childUnreadCount
{
	return childUnreadCount;
}

/* hasDescription
 * Returns YES if this folder has a description, NO otherwise.
 */
-(BOOL)hasDescription
{
	return hasDescription;
}

/* description
 * Returns the folder description.
 */
-(NSString *)description
{
	return description;
}

/* link
 * Returns the folder link.
 */
-(NSString *)link
{
	return link;
}

/* setDescription
 * Sets the folder description.
 */
-(void)setDescription:(NSString *)newDescription
{
	[newDescription retain];
	[description release];
	description = newDescription;
	hasDescription = YES;
}

/* setLink
 * Sets the folder link.
 */
-(void)setLink:(NSString *)newLink
{
	[newLink retain];
	[link release];
	link = newLink;
	hasDescription = YES;
}

/* name
 * Returns the item name
 */
-(NSString *)name
{
	return name;
}

/* setName
 * Updates the folder name.
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* setPermissions
 * Updates the permissions mask.
 */
-(void)setPermissions:(NSInteger)newPermissions
{
	permissions = newPermissions;
}

/* messageFromID
 */
-(VMessage *)messageFromID:(NSInteger)messageId
{
	NSAssert(isMessages, @"Folder's cache of messages should be initialized before messageFromID can be used");
	return [messages objectForKey:[NSNumber numberWithLong:(long)messageId]];
}

/* messages
 */
-(NSArray *)messages
{
	return [messages allValues];
}

/* setUnreadCount
 */
-(void)setUnreadCount:(NSInteger)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", name);
	if (unreadCount != count)
	{
		unreadCount = count;
		isUnreadCountChanged = YES;
	}
}

/* setPrioritytUnreadCount
 */
-(void)setPriorityUnreadCount:(NSInteger)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative priority unread count on folder %@", name);
	if (priorityUnreadCount != count)
	{
		priorityUnreadCount = count;
		isUnreadCountChanged = YES;
	}
}

/* setChildUnreadCount
 * Update a separate count of the total number of unread messages
 * in all child folders.
 */
-(void)setChildUnreadCount:(NSInteger)count
{
	NSAssert1(count >= 0, @"Attempting to set a negative unread count on folder %@", name);
	childUnreadCount = count;
}

/* isUnreadCountChanged
 */
-(BOOL)isUnreadCountChanged
{
	return isUnreadCountChanged;
}

/* resetUnreadCountChanged
 */
-(void)resetUnreadCountChanged
{
	isUnreadCountChanged = NO;
}

/* clearMessages
 * Empty the folder's array of messages.
 */
-(void)clearMessages
{
	[messages removeAllObjects];
	isMessages = NO;
}

/* addMessage
 */
-(void)addMessage:(VMessage *)newMessage
{
	[messages setObject:newMessage forKey:[NSNumber numberWithLong:(long)[newMessage messageId]]];
	isMessages = YES;
}

/* deleteMessage
 */
-(void)deleteMessage:(NSInteger)messageId
{
	NSAssert(isMessages, @"Folder's cache of messages should be initialized before deleteMessage can be used");
	[messages removeObjectForKey:[NSNumber numberWithLong:(long)messageId]];
}

/* markFolderEmpty
 * Mark this folder as empty on the service
 */
-(void)markFolderEmpty
{
	isMessages = YES;
}

/* messageCount
 */
-(NSInteger)messageCount
{
	return isMessages ? (NSInteger)[messages count] : -1;
}

/* folderCompare
 * Returns the result of comparing two items
 */
-(NSComparisonResult)folderCompare:(Folder *)otherObject
{
	return [name caseInsensitiveCompare:[otherObject name]];
}

/* topLevelFolderCompare
 * Returns the result of comparing two items (top level only).
 * Put CIX Conferencing last, always.
 */
-(NSComparisonResult)topLevelFolderCompare:(Folder *)otherObject
{
NSString * cixConfs = @"CIX Conferences";

	if ([name caseInsensitiveCompare:[otherObject name]] == NSOrderedSame)
		return NSOrderedSame;
	else if ( [ name caseInsensitiveCompare:cixConfs] == NSOrderedSame )
		return NSOrderedDescending;
	else if ([ [ otherObject name] caseInsensitiveCompare:cixConfs] == NSOrderedSame)
		return NSOrderedAscending;
	else
		return [name caseInsensitiveCompare:[otherObject name]];
}


/* objectSpecifier
 */
-(NSScriptObjectSpecifier *)objectSpecifier
{
    NSArray * folders = [[NSApp delegate] folders];
    NSUInteger index = [folders indexOfObjectIdenticalTo:self];
    if (index != NSNotFound)
	{
        NSScriptObjectSpecifier *containerRef = [[NSApp delegate] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:(NSScriptClassDescription *)[NSApp classDescription] containerSpecifier:containerRef key:@"folders" index:index] autorelease];
    }
	return nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[messages release];
	[description release];
	[link release];
	[name release];
	[super dealloc];
}
@end
