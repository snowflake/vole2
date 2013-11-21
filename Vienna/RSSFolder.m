//
//  RSSFolder.m
//  Vienna
//
//  Created by Steve on 4/27/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import "RSSFolder.h"

@implementation RSSFolder

/* initWithId
 * Initialise the object.
 */
-(id)initWithId:(Folder *)theFolder subscriptionURL:(NSString *)url update:(NSDate *)update
{
	if ((self = [super init]) != nil)
	{
		folder = [theFolder retain];
		subscriptionURL = [url retain];
		lastUpdate = [update retain];
	}
	return self;
}

/* folderId
 * Return the ID of the folder to which this subscription belongs.
 */
-(NSInteger)folderId
{
	return [folder itemId];
}

/* folder
 * Return the folder associated with this RSS folder
 */
-(Folder *)folder
{
	return folder;
}

/* subscriptionURL
 * Return the URL of the subscription.
 */
-(NSString *)subscriptionURL
{
	return subscriptionURL;
}

/* setSubscriptionURL
 * Changes the URL of the subscription.
 */
-(void)setSubscriptionURL:(NSString *)newSubscriptionURL
{
	[newSubscriptionURL retain];
	[subscriptionURL release];
	subscriptionURL = newSubscriptionURL;
}

/* lastUpdate
 * Return the date of the last update from the feed.
 */
-(NSDate *)lastUpdate
{
	return lastUpdate;
}

/* setLastUpdate
 * Sets the last update date for this RSS feed.
 */
-(void)setLastUpdate:(NSDate *)newLastUpdate
{
	[newLastUpdate retain];
	[lastUpdate release];
	lastUpdate = newLastUpdate;
}

/* RSSFolderCompare
 * Returns the result of comparing two items
 */
-(NSComparisonResult)RSSFolderCompare:(RSSFolder *)otherObject
{
	return [[[self folder] name] caseInsensitiveCompare:[[otherObject folder] name]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[folder release];
	[subscriptionURL release];
	[lastUpdate release];
	[super dealloc];
}
@end
