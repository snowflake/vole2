//
//  ViennaApp.m
//  Vienna
//
//  Created by Steve on Tue Jul 06 2004.
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

#import "ViennaApp.h"
#import "AppController.h"
#import "PreferenceNames.h"
#import "FoldersTree.h"

@implementation ViennaApp

/* handleGetMessages
 */
-(void)handleGetMessages:(NSScriptCommand *)name
{
    (void)name;
	[[self delegate] getMessages:nil];
}

/* applicationVersion
 * Return the applications version number.
 */
-(NSString *)applicationVersion
{
	NSBundle * appBundle = [NSBundle mainBundle];
	NSDictionary * fileAttributes = [appBundle infoDictionary];
	return [fileAttributes objectForKey:@"CFBundleShortVersionString"];
}

/* folders
 * Return a flat array of all folders
 */
-(NSArray *)folders
{
	return [[self delegate] folders];
}

/* isConnecting
 * Return whether or not Vienna is in the process of connecting.
 */
-(BOOL)isConnecting
{
	return [[self delegate] isConnecting];
}

/* unreadCount
 * Return the number of unread messages.
 */
-(NSInteger)unreadCount
{
	Database * db = [[self delegate] database];
	Folder * rootFolder = [db folderFromID:[db conferenceNodeID]];
	return [rootFolder childUnreadCount];
}

/* currentFolder
 * Retrieves the current folder
 */
-(Folder *)currentFolder
{
	Database * db = [[self delegate] database];
	return [db folderFromID:[[self delegate] currentFolderId]];
}

/* checkFrequency
 * Return the frequency with which we check for new messages
 */
-(NSInteger)checkFrequency
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_CheckFrequency];
}

/* setCheckFrequency
 * Updates the check frequency and then updates the preferences.
 */
-(void)setCheckFrequency:(NSInteger)newFrequency
{
	[self internalSetCheckFrequency:newFrequency];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetCheckFrequency
 * Updates the check frequency.
 */
-(void)internalSetCheckFrequency:(NSInteger)newFrequency
{
	[[NSUserDefaults standardUserDefaults] setInteger:newFrequency forKey:MAPref_CheckFrequency];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_CheckFrequencyChange" object:nil];
}

/* quoteColour
 * Return the current quote colour.
 */
-(NSColor *)quoteColour
{
	NSData * colourData;
	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_QuoteColour];
	return [NSUnarchiver unarchiveObjectWithData:colourData];
}

/* setQuoteColour
 * Changes the quote colour then updates the preferences.
 */
-(void)setQuoteColour:(NSColor *)newQuoteColour
{
	[self internalSetQuoteColour:newQuoteColour];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetQuoteColour
 * Changes the quote colour.
 */
-(void)internalSetQuoteColour:(NSColor *)newQuoteColour
{
	NSData * quoteColourAsData = [NSArchiver archivedDataWithRootObject:newQuoteColour];
	[[NSUserDefaults standardUserDefaults] setObject:quoteColourAsData forKey:MAPref_QuoteColour];

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_QuoteColourChange" object:quoteColourAsData];
}

/* priorityColour
 * Return the current priority colour.
 */
-(NSColor *)priorityColour
{
	NSData * colourData;
	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_PriorityColour];
	return [NSUnarchiver unarchiveObjectWithData:colourData];
}

/* setPriorityColour
 * Changes the priority colour then updates the preferences.
 */
-(void)setPriorityColour:(NSColor *)newPriorityColour
{
	[self internalSetPriorityColour:newPriorityColour];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetPriorityColour
 * Changes the priority colour.
 */
-(void)internalSetPriorityColour:(NSColor *)newPriorityColour
{
	NSData * priorityColourAsData = [NSArchiver archivedDataWithRootObject:newPriorityColour];
	[[NSUserDefaults standardUserDefaults] setObject:priorityColourAsData forKey:MAPref_PriorityColour];
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_PriorityColourChange" object:priorityColourAsData];
}

/* ignoredColour
 * Return the current ignored colour then updates the preferences.
 */
-(NSColor *)ignoredColour
{
	NSData * colourData;
	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_IgnoredColour];
	return [NSUnarchiver unarchiveObjectWithData:colourData];
}

/* setIgnoredColour
 * Changes the ignored colour.
 */
-(void)setIgnoredColour:(NSColor *)newIgnoredColour
{
	[self internalSetIgnoredColour:newIgnoredColour];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
}

/* internalSetIgnoredColour
 * Changes the ignored colour.
 */
-(void)internalSetIgnoredColour:(NSColor *)newIgnoredColour
{
	NSData * ignoredColourAsData = [NSArchiver archivedDataWithRootObject:newIgnoredColour];
	[[NSUserDefaults standardUserDefaults] setObject:ignoredColourAsData forKey:MAPref_IgnoredColour];
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_IgnoredColourChange" object:ignoredColourAsData];
}
@end
