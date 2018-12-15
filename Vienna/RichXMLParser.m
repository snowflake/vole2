//
//  RichXMLParser.m
//  Vienna
//
//  Created by Steve on 5/22/05.
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

#import "RichXMLParser.h"
#import <CoreFoundation/CoreFoundation.h>
#import "StringExtensions.h"

@interface FeedItem (Private)
	-(void)setTitle:(NSString *)newTitle;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setAuthor:(NSString *)newAuthor;
	-(void)setDate:(NSDate *)newDate;
	-(void)setLink:(NSString *)newLink;
@end

@interface RichXMLParser (Private)
	-(void)reset;
	-(BOOL)initRSSFeed:(XMLParser *)feedTree isRDF:(BOOL)isRDF;
	-(XMLParser *)channelTree:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedHeader:(XMLParser *)feedTree;
	-(BOOL)initRSSFeedItems:(XMLParser *)feedTree;
	-(BOOL)initAtomFeed:(XMLParser *)feedTree;
	-(void)setTitle:(NSString *)newTitle;
	-(void)setLink:(NSString *)newLink;
	-(void)setDescription:(NSString *)newDescription;
	-(void)setLastModified:(NSDate *)newDate;
	-(void)ensureTitle:(FeedItem *)item;
@end

@implementation FeedItem

/* init
 * Creates a FeedItem instance
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setTitle:@"No title"];
		[self setDescription:@"No description"];
		[self setAuthor:@"None"];
		[self setDate:nil];
		[self setLink:@""];
	}
	return self;
}

/* setTitle
 * Set the item title.
 */
-(void)setTitle:(NSString *)newTitle
{
	title = newTitle;
}

/* setDescription
 * Set the item description.
 */
-(void)setDescription:(NSString *)newDescription
{
	description = newDescription;
}

/* setAuthor
 * Set the item author.
 */
-(void)setAuthor:(NSString *)newAuthor
{
	author = newAuthor;
}

/* setDate
 * Set the item date
 */
-(void)setDate:(NSDate *)newDate
{
	date = newDate;
}

/* setLink
 * Set the item link.
 */
-(void)setLink:(NSString *)newLink
{
	link = newLink;
}

/* setGuid
 * Set the item GUID
 */
-(void)setGuid:(NSString *)newId
{
	guid = newId;
}

/* title
 * Returns the item title.
 */
-(NSString *)title
{
	return title;
}

/* description
 * Returns the item description
 */
-(NSString *)description
{
	return description;
}

/* author
 * Returns the item author
 */
-(NSString *)author
{
	return author;
}

/* date
 * Returns the item date
 */
-(NSDate *)date
{
	return date;
}

/* link
 * Returns the item link.
 */
-(NSString *)link
{
	return link;
}

/* guid
 * Returns the item link.
 */
-(NSString *)guid
{
	return guid;
}

/* dealloc
 * Clean up when we're released.
 */
@end

@implementation RichXMLParser

/* init
 * Creates a RichXMLParser instance.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		title = nil;
		description = nil;
		lastModified = nil;
		link = nil;
		items = nil;
	}
	return self;
}

/* reset
 * Reset to remove existing feed info.
 */
-(void)reset
{
	title = nil;
	description = nil;
	link = nil;
	guid = nil;
	items = nil;
}

/* loadFromURL
 * Loads our instance from the specified URL and initialises the tree with the feed header information.
 */
-(BOOL)loadFromURL:(NSString *)urlString
{
	BOOL success = NO;

	[self reset];
	NSAssert(urlString != nil, @"URL passed to RichXMLParser:initWithURL is nil!");
	NSURL * url = [NSURL URLWithString:urlString];
	NSURLHandle * urlHandle = [url URLHandleUsingCache:NO];
	NSData * feedData = [urlHandle resourceData];
	if (feedData != nil)
	{
		if ([self initWithData:feedData])
		{
			XMLParser * subtree;

			// If this RSS?
			if ((subtree = [self treeByName:@"rss"]) != nil)
				success = [self initRSSFeed:subtree isRDF:NO];

			// If this RSS:RDF?
			else if ((subtree = [self treeByName:@"rdf:RDF"]) != nil)
				success = [self initRSSFeed:subtree isRDF:YES];

			// Atom?
			else if ((subtree = [self treeByName:@"feed"]) != nil)
				success = [self initAtomFeed:subtree];
		}
	}
	return success;
}

/* initRSSFeed
 * Prime the feed with header and items from an RSS feed
 */
-(BOOL)initRSSFeed:(XMLParser *)feedTree isRDF:(BOOL)isRDF
{
	BOOL success = [self initRSSFeedHeader:[self channelTree:feedTree]];
	if (success)
	{
		if (isRDF)
			success = [self initRSSFeedItems:feedTree];
		else
			success = [self initRSSFeedItems:[self channelTree:feedTree]];
	}
	return success;
}

/* channelTree
 * Return the root of the RSS feed's channel.
 */
-(XMLParser *)channelTree:(XMLParser *)feedTree
{
	XMLParser * channelTree = [feedTree treeByName:@"channel"];
	if (channelTree == nil)
		channelTree = [feedTree treeByName:@"rss:channel"];
	return channelTree;
}

/* initRSSFeedHeader
 * Parse an RSS feed header items.
 */
-(BOOL)initRSSFeedHeader:(XMLParser *)feedTree
{
	BOOL success = YES;
	
	// Iterate through the channel items
	NSInteger count = [feedTree countOfChildren];
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];

		// Parse title
		if ([nodeName isEqualToString:@"title"])
		{
			[self setTitle:[XMLParser processAttributes:[subTree valueOfElement]]];
			continue;
		}

		// Parse description
		if ([nodeName isEqualToString:@"description"])
		{
			[self setDescription:[subTree valueOfElement]];
			continue;
		}			
		
		// Parse link
		if ([nodeName isEqualToString:@"link"])
		{
			[self setLink:[subTree valueOfElement]];
			continue;
		}			
		
		// Parse the date when this feed was last updated
		if ([nodeName isEqualToString:@"lastBuildDate"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
		
		// Parse item date
		if ([nodeName isEqualToString:@"dc:date"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
	}
	return success;
}

/* initRSSFeedItems
 * Parse the items from an RSS feed
 */
-(BOOL)initRSSFeedItems:(XMLParser *)feedTree
{
	BOOL success = YES;

	// Allocate an items array
	items = [[NSMutableArray alloc] initWithCapacity:10];
	
	// Iterate through the channel items
	NSInteger count = [feedTree countOfChildren];
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];
		
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([nodeName isEqualToString:@"item"])
		{
			FeedItem * newItem = [[FeedItem alloc] init];
			NSInteger itemCount = [subTree countOfChildren];
			NSInteger itemIndex;
			
			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];

				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					[newItem setTitle:[XMLParser processAttributes:[subItemTree valueOfElement]]];
					continue;
				}
				
				// Parse item description
				if ([itemNodeName isEqualToString:@"description"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"author"])
				{
					[newItem setAuthor:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"dc:creator"])
				{
					[newItem setAuthor:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"dc:date"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"link"])
				{
					[newItem setLink:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"pubDate"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}

				// Get Guid (if present)
				if ([itemNodeName isEqualToString:@"id"] || [itemNodeName isEqualToString:@"guid"] )
				{
					[newItem setGuid:[subItemTree valueOfElement]];
					continue;
				}
				
			}
			
			// Derive any missing title
			[self ensureTitle:newItem];
			[items addObject:newItem];
		}
	}
	return success;
}

/* initAtomFeed
 * Prime the feed with header and items from an Atom feed
 */
-(BOOL)initAtomFeed:(XMLParser *)feedTree
{
	// Allocate an items array
	items = [[NSMutableArray alloc] initWithCapacity:10];
	
	// Iterate through the atom items
	NSInteger count = [feedTree countOfChildren];
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * subTree = [feedTree treeByIndex:index];
		NSString * nodeName = [subTree nodeName];
		
		// Parse title
		if ([nodeName isEqualToString:@"title"])
		{
			[self setTitle:[XMLParser processAttributes:[subTree valueOfElement]]];
			continue;
		}
		
		// Parse description
		if ([nodeName isEqualToString:@"tagline"])
		{
			[self setDescription:[subTree valueOfElement]];
			continue;
		}			
		
		// Parse link
		if ([nodeName isEqualToString:@"link"])
		{
			[self setLink:[subTree valueOfAttribute:@"href"]];
			continue;
		}			
		
		// Parse the date when this feed was last updated
		if ([nodeName isEqualToString:@"modified"])
		{
			NSString * dateString = [subTree valueOfElement];
			[self setLastModified:[XMLParser parseXMLDate:dateString]];
			continue;
		}
		
		// Parse a single item to construct a FeedItem object which is appended to
		// the items array we maintain.
		if ([nodeName isEqualToString:@"entry"])
		{
			FeedItem * newItem = [[FeedItem alloc] init];
			NSInteger itemCount = [subTree countOfChildren];
			NSInteger itemIndex;
			
			for (itemIndex = 0; itemIndex < itemCount; ++itemIndex)
			{
				XMLParser * subItemTree = [subTree treeByIndex:itemIndex];
				NSString * itemNodeName = [subItemTree nodeName];
				
				// Parse item title
				if ([itemNodeName isEqualToString:@"title"])
				{
					[newItem setTitle:[XMLParser processAttributes:[subItemTree valueOfElement]]];
					continue;
				}

				// Parse item description
				if ([itemNodeName isEqualToString:@"content"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item description
				if ([itemNodeName isEqualToString:@"summary"])
				{
					[newItem setDescription:[subItemTree valueOfElement]];
					continue;
				}
				
				// Parse item author
				if ([itemNodeName isEqualToString:@"author"])
				{
					XMLParser * emailTree = [subItemTree treeByName:@"name"];
					[newItem setAuthor:[emailTree valueOfElement]];
					continue;
				}

				// Parse item link
				if ([itemNodeName isEqualToString:@"link"])
				{
					[newItem setLink:[subItemTree valueOfAttribute:@"href"]];
					continue;
				}
				
				// Parse item date
				if ([itemNodeName isEqualToString:@"modified"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}

				// Parse item date (some feeds use updated rather than modified)
				if ([itemNodeName isEqualToString:@"updated"])
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
				
				// Parse item date 
				if ([itemNodeName isEqualToString:@"pubDate"] && [newItem date] == nil)
				{
					NSString * dateString = [subItemTree valueOfElement];
					[newItem setDate:[XMLParser parseXMLDate:dateString]];
					continue;
				}
				
				// Get Guid (if present)
				if ([itemNodeName isEqualToString:@"id"] || [itemNodeName isEqualToString:@"guid"] )
				{
					[newItem setGuid:[subItemTree valueOfElement]];
					continue;
				}
			}
			
			// Derive any missing title
			[self ensureTitle:newItem];
			[items addObject:newItem];
		}
	}
	return YES;
}

/* setTitle
 * Set this feed's title string.
 */
-(void)setTitle:(NSString *)newTitle
{
	title = newTitle;
}

/* setDescription
 * Set this feed's description string.
 */
-(void)setDescription:(NSString *)newDescription
{
	description = newDescription;
}

/* setLink
 * Sets this feed's link
 */
-(void)setLink:(NSString *)newLink
{
	link = newLink;
}

/* setLastModified
 * Set the date when this feed was last updated.
 */
-(void)setLastModified:(NSDate *)newDate
{
	lastModified = newDate;
}

/* title
 * Return the title string.
 */
-(NSString *)title
{
	return title;
}

/* description
 * Return the description string.
 */
-(NSString *)description
{
	return description;
}

/* link
 * Returns the URL of this feed
 */
-(NSString *)link
{
	return link;
}

/* items
 * Returns the array of items.
 */
-(NSArray *)items
{
	return items;
}

/* lastModified
 * Returns the feed's last update
 */
-(NSDate *)lastModified
{
	return lastModified;
}

/* guid
 * Returns the item link.
 */
-(NSString *)guid
{
	return guid;
}

/* ensureTitle
 * Make sure we have a title and synthesize one from the description if we don't.
 */
-(void)ensureTitle:(FeedItem *)item
{
	if (![item title] || [[item title] isEqualToString:@""])
	{
		NSData * chardata = [[NSData alloc] initWithBytes:[[item description] UTF8String] length:[[item description] length]];
		NSMutableAttributedString * attrText = [[NSMutableAttributedString alloc] initWithHTML:chardata documentAttributes:nil];
		[item setTitle:[[attrText string] firstNonBlankLine]];
	}
}

/* dealloc
 * Clean up afterwards.
 */
@end
