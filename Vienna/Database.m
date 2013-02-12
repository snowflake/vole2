//
//  Database.m
//  Vienna
//
//  Created by Steve on Tue Feb 03 2004.
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

#import "Database.h"
#import "StringExtensions.h"
#import "PreferenceNames.h"

// Private functions
@interface Database (Private)
	-(void)verifyThreadSafety;
	-(int)topLevelFolderByName:(NSString *)wantedName;
	-(void)executeSQL:(NSString *)sqlStatement;
	-(void)executeSQLWithFormat:(NSString *)sqlStatement, ...;
	-(NSString *)folderPathNameHelper:(Folder *)folder;
	-(void)initPersonArray;
@end

// Indexes into folder image array
enum {
	MA_FirstIcon = 0,
	MA_FolderIcon = MA_FirstIcon,
	MA_OutboxIcon,
	MA_DraftIcon,
	MA_ConferenceIcon,
	MA_SearchFolderIcon,
	MA_LockedFolderIcon,
	MA_RSSFolderIcon,
	MA_RSSFeedIcon,
	MA_Max_Icons
};

@implementation Database

/* init
 * General object initialization.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		inTransaction = NO;
		sqlDatabase = NULL;
		initializedFoldersArray = NO;
		initializedTasksArray = NO;
		initializedForumArray = NO;
		initializedSearchFoldersArray = NO;
		initializedPersonArray = NO;
		initializedRSSArray = NO;
		countOfPriorityUnread = 0;
		cachedRSSNodeID = -1;
		searchFoldersArray = [[NSMutableDictionary dictionary] retain];
		foldersArray = [[NSMutableDictionary dictionary] retain];
		forumArray = [[NSMutableDictionary dictionary] retain];
		categoryArray = [[NSMutableDictionary dictionary] retain];
		tasksArray = [[NSMutableArray alloc] init];
		personArray = [[NSMutableDictionary dictionary] retain];
		rssFeedArray = [[NSMutableDictionary dictionary] retain];

		// Preload the images
		iconArray = [[NSArray arrayWithObjects:
			[NSImage imageNamed:@"smallFolder.tiff"],
			[NSImage imageNamed:@"outboxFolder.tiff"],
			[NSImage imageNamed:@"draftFolder.tiff"],
			[NSImage imageNamed:@"conferenceFolder.tiff"],
			[NSImage imageNamed:@"searchFolder.tiff"],
			[NSImage imageNamed:@"lockedFolder.tiff"],
			[NSImage imageNamed:@"rssFolder.tiff"],
			[NSImage imageNamed:@"rssFeed.tiff"],
			nil] retain];
	}
	return self;
}

/* initDatabase
 * Initalizes the database. The database is first checked to ensure it exists
 * and, if not, it is created with all the tables.
 */
-(BOOL)initDatabase:(NSString *)databaseFileName
{
	// Don't allow nested opens
	if (sqlDatabase)
		return NO;

	// Fully expand the path and make sure it exists because if the
	// database file itself doesn't exist, we want to create it and
	// we can't create it on a non-existent path.
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSString * qualifiedDatabaseFileName = [databaseFileName stringByExpandingTildeInPath];
	NSString * databaseFolder = [qualifiedDatabaseFileName stringByDeletingLastPathComponent];
	BOOL isDir;

	if (![fileManager fileExistsAtPath:databaseFolder isDirectory:&isDir])
	{
		if (![fileManager createDirectoryAtPath:databaseFolder attributes:NULL])
		{
			NSRunAlertPanel(NSLocalizedString(@"Cannot create database folder", nil),
							NSLocalizedString(@"Cannot create database folder text", nil),
							NSLocalizedString(@"Close", nil), @"", @"",
							databaseFolder);
			return NO;
		}
	}
	
	// Open the database at the well known location
	sqlDatabase = [[SQLDatabase alloc] initWithFile:qualifiedDatabaseFileName];
	if (!sqlDatabase || ![sqlDatabase open])
		return NO;

	// Get the info table. If it doesn't exist then the database is new
	SQLResult * results = [sqlDatabase performQuery:@"select version from info"];
	databaseVersion = 0;
	if (results && [results rowCount])
	{
		NSString * versionString = [[results rowAtIndex:0] stringForColumn:@"version"];
		databaseVersion = [versionString intValue];
	}
	// static analyser complains
	// [results release];

	// Save this thread handle to ensure we trap cases of calling the db on
	// the wrong thread.
	mainThread = [NSThread currentThread];
	
	// Create the tables when the database is empty.
	if (databaseVersion == 0)
	{
		// Create the tables
		[self executeSQL:@"create table info (version, last_opened)"];
		[self executeSQL:@"create table folders (folder_id integer primary key, parent_id, foldername, unread_count, priority_unread_count, permissions)"];
		[self executeSQL:@"create table messages (message_id, folder_id, comment_id, read_flag, marked_flag, priority_flag, ignored_flag, title, sender, date, text)"];
		[self executeSQL:@"create table search_folders (folder_id, search_string)"];
		[self executeSQL:@"create table tasks (task_id integer primary key, order_code, action_code, action_data, folder_name, result_code, result_data, last_run, earliest_run)"];

		// Create the built-in folders
		[self executeSQLWithFormat:@"insert into folders (folder_id, foldername, parent_id, priority_unread_count, unread_count, permissions) values (%d, 'Out Basket', -1, 0, 0, %d)", MA_Outbox_NodeID, MA_ReadWrite_Folder];
		[self executeSQLWithFormat:@"insert into folders (folder_id, foldername, parent_id, priority_unread_count, unread_count, permissions) values (%d, 'Draft', -1, 0, 0, %d)", MA_Draft_NodeID, MA_ReadWrite_Folder];
		[self executeSQLWithFormat:@"insert into folders (folder_id, foldername, parent_id, priority_unread_count, unread_count, permissions) values (%d, 'CIX Conferences', -1, 0, 0, %d)", MA_Conference_NodeID, MA_Empty_Folder];

		// Create a criteria to find all marked messages
		VCriteriaTree * criteriaTree = [[VCriteriaTree alloc] init];
		VCriteria * markedCriteria = [[VCriteria alloc] initWithField:@"Flagged" withOperator:MA_CritOper_Is withValue:@"Yes"];
		[criteriaTree addCriteria:markedCriteria];
		
		NSString * preparedCriteriaString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];

		// Create default search tables.
		[self executeSQLWithFormat:@"insert into folders (foldername, parent_id, unread_count, priority_unread_count, permissions) values ('Marked', -1, 0, 0, %d)", MA_Search_Folder];
		[self executeSQLWithFormat:@"insert into search_folders (folder_id, search_string) values (%d, '%@')", [sqlDatabase lastInsertRowId], preparedCriteriaString];

		// Clean up
		[markedCriteria release];
		[criteriaTree release];

		// Set the initial version
		[self executeSQL:@"insert into info (version) values (5)"];
		
		// Update databaseVersion to indicate that, so far, the db structure is at version 5.0.
		databaseVersion = 5;
	}
	if (databaseVersion < 5)
	{
		NSRunAlertPanel(NSLocalizedString(@"Unrecognised database format", nil),
						NSLocalizedString(@"Unrecognised database format text", nil),
						NSLocalizedString(@"Close", nil), @"", @"",
						qualifiedDatabaseFileName);
		return NO;
	}
	else 
	{
		if (databaseVersion < 7)
		{
			// Create the browser tables
			[self executeSQL:@"create table categories (category_id integer primary key, parent_id, name)"];
			[self executeSQL:@"create table forums (item_id integer primary key, category_id, name, description, status, moderators, last_date)"];

			// Bump up the version
			[self executeSQL:@"update info set version=7"];
			
			// Update databaseVersion to indicate that, so far, the db structure is at version 7.0.
			databaseVersion = 7;
		}
		if (databaseVersion < 8)
		{
			// Create the people table
			[self executeSQL:@"create table people (person_id integer primary key, name, info)"];

			// Bump up the version
			[self executeSQL:@"update info set version=8"];

			// Update databaseVersion to indicate that, so far, the db structure is at version 8.0.
			databaseVersion = 8;
		}

		// For Vienna 1.4.0 and later, add support for subscribing to RSS feeds via a separate table that
		// tracks the feed URL and other information.
		if (databaseVersion < 9)
		{
			// Create the RSS table
			[self executeSQL:@"create table rss_feeds (folder_id, feed_url, last_update)"];
			[self executeSQL:@"create table folder_descriptions (folder_id, description, link)"];
			[self executeSQLWithFormat:@"insert into folders (foldername, parent_id, priority_unread_count, unread_count, permissions) values ('RSS Subscriptions', -1, 0, 0, %d)", MA_Empty_Folder];

			// Rename Conferences folder to CIX Conferences
			[self executeSQLWithFormat:@"update folders set foldername='CIX Conferences' where folder_id=%d", MA_Conference_NodeID];

			// Bump up the version
			[self executeSQL:@"update info set version=9"];
			
			// Update databaseVersion to indicate that, so far, the db structure is at version 9.0.
			databaseVersion = 9;
		}
		
		// Add some new indexes
		if (databaseVersion < 10)
		{
			[self executeSQL:@"delete index messages_idx"];
			[self executeSQL:@"create index messages_comment_idx on messages (comment_id)"];
			[self executeSQL:@"create index messages_folder_idx on messages (folder_id)"];
			
			// Bump up the version
			[self executeSQL:@"update info set version=10"];

			// Update databaseVersion to indicate that, so far, the db structure is at version 10.0.
			databaseVersion = 10;
		}

		// Add RSS guid
		if (databaseVersion < 11)
		{
			[self executeSQL:@"alter table messages add column rss_guid"];
			[self executeSQL:@"create index messages_guid_idx on messages (rss_guid)"];
			
			// Bump up the version
			[self executeSQL:@"update info set version=11"];

			// Update databaseVersion to indicate that, so far, the db structure is at version 10.0.
			databaseVersion = 11;
		}
	}

	// Initial check if the database is read-only
	[self syncLastUpdate];
	
	// Create fields
	fieldsByName = [[NSMutableDictionary dictionary] retain];
	fieldsByTitle = [[NSMutableDictionary dictionary] retain];
	fieldsOrdered = [[NSMutableArray alloc] init];
	
	[self addField:MA_Column_MessageUnread title:@"Read" type:MA_FieldType_Flag tag:MA_ID_MessageUnread sqlField:@"read_flag" visible:YES width:17];
	[self addField:MA_Column_MessageFlagged title:@"Flagged" type:MA_FieldType_Flag tag:MA_ID_MessageFlagged sqlField:@"marked_flag" visible:YES width:15];
	[self addField:MA_Column_MessagePriority title:@"Priority" type:MA_FieldType_Flag tag:MA_ID_MessagePriority sqlField:@"priority_flag" visible:NO width:15];
	[self addField:MA_Column_MessageIgnored title:@"Ignored" type:MA_FieldType_Flag tag:MA_ID_MessageIgnored sqlField:@"ignored_flag" visible:NO width:15];
	[self addField:MA_Column_MessageId title:@"Number" type:MA_FieldType_Integer tag:MA_ID_MessageId sqlField:@"message_id" visible:YES width:72];
	[self addField:MA_Column_MessageComment title:@"Comment" type:MA_FieldType_Integer tag:MA_ID_MessageComment sqlField:@"comment_id" visible:NO width:50];
	[self addField:MA_Column_MessageFolderId title:@"Folder" type:MA_FieldType_Folder tag:MA_ID_MessageFolderId sqlField:@"folder_id" visible:NO width:50];
	[self addField:MA_Column_MessageFrom title:@"From" type:MA_FieldType_String tag:MA_ID_MessageFrom sqlField:@"sender" visible:YES width:138];
	[self addField:MA_Column_MessageTitle title:@"Subject" type:MA_FieldType_String tag:MA_ID_MessageTitle sqlField:@"title" visible:YES width:472];
	[self addField:MA_Column_MessageDate title:@"Date Posted" type:MA_FieldType_Date tag:MA_ID_MessageDate sqlField:@"date" visible:YES width:152];
	[self addField:MA_Column_MessageText title:@"Text" type:MA_FieldType_String tag:MA_ID_MessageText sqlField:@"text" visible:NO width:152];
	return YES;
}

/* executeSQL
 * Executes the specified SQL statement and discards the result. Should be used for
 * SQL statements that do not return results.
 */
-(void)executeSQL:(NSString *)sqlStatement
{
	SQLResult * result = [sqlDatabase performQuery:sqlStatement];
	// static analyser complains
	// [result release];
}

/* executeSQLWithFormat
 * Executes the specified SQL statement and discards the result. Should be used for
 * SQL statements that do not return results.
 */
-(void)executeSQLWithFormat:(NSString *)sqlStatement, ...
{
	va_list arguments;
	va_start(arguments, sqlStatement);
	NSString * query = [[NSString alloc] initWithFormat:sqlStatement arguments:arguments];
	SQLResult * result = [sqlDatabase performQuery:query];
	[query release];
	// static analyser complains
	// [result release];
}

/* verifyThreadSafety
 * In debug mode we assert if the caller thread isn't the thread on which the database
 * was created. In release mode, we do nothing.
 */
-(void)verifyThreadSafety
{
	NSAssert([NSThread currentThread] == mainThread, @"Calling database on wrong thread!");
}

/* syncLastUpdate
 * Call this function to update the field in the info table which contains the last_updated
 * date. This is needed by other users to determine when to resynchronize.
 */
-(void)syncLastUpdate
{
	[self verifyThreadSafety];
	SQLResult * result = [sqlDatabase performQueryWithFormat:@"update info set last_opened='%@'", [NSDate date]];
	readOnly = (result == nil);
	// static analyser complains
	// [result release];
}

/* addField
 * Add the specified field to our fields array.
 */
-(void)addField:(NSString *)name title:(NSString *)title type:(int)type tag:(int)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(int)width
{
	VField * field = [[VField alloc] init];
	if (field != nil)
	{
		[field setName:name];
		[field setTitle:title];
		[field setType:type];
		[field setTag:tag];
		[field setVisible:visible];
		[field setWidth:width];
		[field setSqlField:sqlField];
		[fieldsOrdered addObject:field];
		[fieldsByName setValue:field forKey:name];
		[fieldsByTitle setValue:field forKey:title];
		[field release];
	}
}

/* arrayOfFields
 * Return the array of fields.
 */
-(NSArray *)arrayOfFields
{
	return fieldsOrdered;
}

/* fieldByIdentifier
 * Given an identifier, this function returns the field represented by
 * that identifier.
 */
-(VField *)fieldByIdentifier:(NSString *)identifier
{
	return [fieldsByName valueForKey:identifier];
}

/* fieldByTitle
 * Given an title, this function returns the field represented by
 * that title.
 */
-(VField *)fieldByTitle:(NSString *)title
{
	return [fieldsByTitle valueForKey:title];
}

/* databaseVersion
 * Return the database version.
 */
-(int)databaseVersion
{
	return databaseVersion;
}

/* readOnly
 * Returns whether or not this database is read-only.
 */
-(BOOL)readOnly
{
	return readOnly;
}

/* imageForFolder
 * Returns an NSImage item that represents the specified folder.
 */
-(NSImage *)imageForFolder:(Folder *)folder
{
	if ([folder itemId] == MA_Draft_NodeID)
		return [iconArray objectAtIndex:MA_DraftIcon];
	if ([folder itemId] == [self conferenceNodeID])
		return [iconArray objectAtIndex:MA_ConferenceIcon];
	if ([folder itemId] == [self rssNodeID])
		return [iconArray objectAtIndex:MA_RSSFolderIcon];
	if ([folder itemId] == MA_Outbox_NodeID)
		return [iconArray objectAtIndex:MA_OutboxIcon];
	if (IsSearchFolder(folder))
		return [iconArray objectAtIndex:MA_SearchFolderIcon];
	if (IsRSSFolder(folder))
		return [iconArray objectAtIndex:MA_RSSFeedIcon];
	if (IsFolderLocked(folder))
		return [iconArray objectAtIndex:MA_LockedFolderIcon];
	return [iconArray objectAtIndex:MA_FolderIcon];
}

/* setUsername
 * Sets the current user name so that the database can correctly
 * mark messages priority.
 */
-(void)setUsername:(NSString *)newUsername
{
	[newUsername retain];
	[username release];
	username = newUsername;
}

/* beginTransaction
 * Starts a SQL transaction.
 */
-(void)beginTransaction
{
	[self verifyThreadSafety];
	NSAssert(!inTransaction, @"Whoops! Already in a transaction. You forgot to call commitTransaction somewhere");
	[self executeSQL:@"begin transaction"];
	inTransaction = YES;
}

/* commitTransaction
 * Commits a SQL transaction.
 */
-(void)commitTransaction
{
	[self verifyThreadSafety];
	NSAssert(inTransaction, @"Whoops! Not in a transaction. You forgot to call beginTransaction first");
	[self executeSQL:@"commit transaction"];
	inTransaction = NO;
}

/* compactDatabase
 * Compact the database using the vacuum command.
 */
-(void)compactDatabase
{
	[self verifyThreadSafety];
	[self executeSQL:@"vacuum"];
}

/* initForumArray
 * Initialise the forumArray.
 */
-(void)initForumArray
{
	if (!initializedForumArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		[self verifyThreadSafety];
		
		SQLResult * results;
		
		results = [sqlDatabase performQuery:@"select * from forums"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int itemId = [[row stringForColumn:@"item_id"] intValue];
				int categoryId = [[row stringForColumn:@"category_id"] intValue];
				int status = [[row stringForColumn:@"status"] intValue];
				NSString * name = [row stringForColumn:@"name"];
				NSString * description = [row stringForColumn:@"description"];
				NSDate * lastActiveDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"last_date"] doubleValue]];

				Forum * forum = [[Forum alloc] initWithName:name];
				[forum setNodeId:itemId];
				[forum setCategoryId:categoryId];
				[forum setStatus:status];
				[forum setDescription:description];
				[forum setLastActiveDate:lastActiveDate];
				[forumArray setObject:forum forKey:name];
				[forum release];
			}
		}

		// Now get the category list
		results = [sqlDatabase performQuery:@"select * from categories"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int categoryId = [[row stringForColumn:@"category_id"] intValue];
				int parentId = [[row stringForColumn:@"parent_id"] intValue];
				NSString * name = [row stringForColumn:@"name"];
				
				Category * category = [[Category alloc] initWithName:name];
				[category setCategoryId:categoryId];
				[category setParentId:parentId];
				[category setName:name];
				[categoryArray setObject:category forKey:[NSNumber numberWithInt:categoryId]];
				[category release];
			}
		}
		// static analsyer complains
		// [results release];
		initializedForumArray = YES;
	}
}

/* arrayOfCategories
 * Returns an NSArray of all categories with the specified parent.
 */
-(NSArray *)arrayOfCategories:(int)parentId
{
	// Prime the cache
	if (initializedForumArray == NO)
		[self initForumArray];
	
	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [categoryArray objectEnumerator];
		Category * item;
		
		while ((item = [enumerator nextObject]) != nil)
		{
			if ([item parentId] == parentId)
				[newArray addObject:item];
		}
	}
	return [newArray sortedArrayUsingSelector:@selector(categoryCompare:)];
}

/* arrayOfForums
 * Returns an NSArray of all forums with the specified category.
 */
-(NSArray *)arrayOfForums:(int)status inCategory:(int)categoryId
{
	// Prime the cache
	if (initializedForumArray == NO)
		[self initForumArray];

	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [forumArray objectEnumerator];
		Forum * item;

		while ((item = [enumerator nextObject]) != nil)
		{
			if (status == MA_All_Conferences || [item status] == status)
			{
				if (categoryId == -2 || [item categoryId] == categoryId)
					[newArray addObject:item];
			}
		}
	}
	return newArray;
}

/* findCategory
 * Finds the specified category in the children of the given parent category.
 */
-(Category *)findCategory:(int)parentId name:(NSString *)name
{
	NSEnumerator * enumerator = [categoryArray objectEnumerator];
	Category * category = nil;
	
	while ((category = [enumerator nextObject]) != nil)
	{
		if ([category parentId] == parentId && [[category name] isEqualToString:name])
			break;
	}
	return category;
}

/* addCategory
 * Adds a new forum category
 */
-(int)addCategory:(Category *)newCategory
{
	// Prime the cache
	[self initForumArray];
	
	// Exit now if we're read-only
	if (readOnly)
		return -1;

	// Try to locate this category
	Category * category = [self findCategory:[newCategory parentId] name:[newCategory name]];
	if (category != nil)
		[newCategory setCategoryId:[category categoryId]];
	else
	{
		int newItemId;

		// Preprocess the name to make it SQL-friendly
		NSString * preparedName = [SQLDatabase prepareStringForQuery:[newCategory name]];

		// Add a new row into the forums table.
		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"insert into categories (parent_id, name) values (%d, '%@')",
									[newCategory parentId],
									preparedName];
		if (!results)
			return -1;
		
		// Quick way of getting the last autoincrement primary key value (the folder_id).
		newItemId = [sqlDatabase lastInsertRowId];

		// Add this new category to our internal cache
		[newCategory setCategoryId:newItemId];
		[categoryArray setObject:newCategory forKey:[NSNumber numberWithInt:newItemId]];
		// staic analyser complains
		// [results release];
	}
	return [newCategory categoryId];
}

/* addForum
 * Adds a forum to the database. The newForum object should be initialised with the
 * name, description and forum ID (which is the ID of the forum category to which
 * this forum belongs).
 */
-(int)addForum:(Forum *)newForum
{
	// Prime the cache
	[self initForumArray];

	// Exit now if we're read-only
	if (readOnly)
		return -1;

	// Convert the date to a time interval
	NSTimeInterval interval = [[newForum lastActiveDate] timeIntervalSince1970];

	// Preprocess the name and description to make them SQL-friendly
	NSString * preparedName = [SQLDatabase prepareStringForQuery:[newForum name]];
	NSString * preparedDescription = [SQLDatabase prepareStringForQuery:[newForum description]];
	
	// Check whether it is already there. If so, just update the existing
	// information.
	Forum * forum = [forumArray objectForKey:[newForum name]];
	[self verifyThreadSafety];
	if (forum != nil)
	{
		SQLResult * results = [sqlDatabase performQueryWithFormat:
			@"update forums set category_id=%d, status=%d, last_date=%f, description='%@' where item_id=%d",
							[newForum categoryId],
							[newForum status],
							interval,
							preparedDescription,
							[forum nodeId]];
		if (!results)
			return -1;

		// Replace the current object
		[forum setLastActiveDate:[newForum lastActiveDate]];
		[forum setDescription:[newForum description]];
		[forum setStatus:[newForum status]];
		[forum setCategoryId:[newForum categoryId]];
		// static analyser complains
		// [results release];
	}
	else
	{
		int newItemId;

		// Add a new row into the forums table.
		SQLResult * results = [sqlDatabase performQueryWithFormat:
			@"insert into forums (category_id, name, status, last_date, description) values (%d, '%@', %d, %f, '%@')",
								[newForum categoryId],
								preparedName,
								[newForum status],
								interval,
								preparedDescription];
		if (!results)
			return -1;

		// Quick way of getting the last autoincrement primary key value (the folder_id).
		newItemId = [sqlDatabase lastInsertRowId];

		// Add this new forum to our internal cache
		[newForum setNodeId:newItemId];
		[forumArray setObject:newForum forKey:[newForum name]];
		// static analysercomplains
		// [results release];
	}
	return [newForum nodeId];
}

/* addFolderByPath
 * Add a new folder given its full path. If any folder on the path is missing, it is
 * automatically created. All parent folders are created as empty folders by default.
 */
-(int)addFolderByPath:(int)parentId path:(NSString *)path
{
	NSArray * pathComponents = [path componentsSeparatedByString:@"/"];
	int count = [pathComponents count];
	int folderId = parentId;
	int index;
	
	if (count < 1)
		return -1;

	for (index = 0; index < count - 1; ++index)
	{
		NSString * pathItem = [pathComponents objectAtIndex:index];
		folderId = [self addFolder:folderId folderName:pathItem permissions:MA_Empty_Folder mustBeUnique:YES];
	}

	NSString * pathItem = [pathComponents objectAtIndex:index];
	return [self addFolder:folderId folderName:pathItem permissions:MA_ReadOnly_Folder mustBeUnique:YES];
}

/* initRSSArray
 * Initialise the rssFeedArray.
 */
-(void)initRSSArray
{
	if (!initializedRSSArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		[self verifyThreadSafety];
		
		SQLResult * results;

		results = [sqlDatabase performQuery:@"select * from rss_feeds"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				NSString * url = [row stringForColumn:@"feed_url"];
				NSDate * update = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"last_update"] doubleValue]];

				Folder * folder = [self folderFromID:folderId];
				RSSFolder * rssFolder = [[RSSFolder alloc] initWithId:folder subscriptionURL:url update:update];
				[rssFeedArray setObject:rssFolder forKey:[NSNumber numberWithInt:folderId]];
				[rssFolder release];
			}
		}
		// static analyser complains
		// [results release];
		initializedRSSArray = YES;
	}
}

/* arrayOfRSSFolders
 * Return an array of RSS folders.
 */
-(NSArray *)arrayOfRSSFolders
{
	// Prime the cache
	if (initializedRSSArray == NO)
		[self initRSSArray];

	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [rssFeedArray objectEnumerator];
		RSSFolder * item;

		while ((item = [enumerator nextObject]) != nil)
			[newArray addObject:item];
	}
	return [newArray sortedArrayUsingSelector:@selector(RSSFolderCompare:)];
}

/* rssFolderFromURL
 * Returns the RSSFolder that is subscribed to the specified feed URL.
 */
-(RSSFolder *)rssFolderFromURL:(NSString *)url
{
	if (initializedRSSArray == NO)
		[self initRSSArray];

	NSEnumerator * enumerator = [rssFeedArray objectEnumerator];
	RSSFolder * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([[item subscriptionURL] isEqualToString:url])
			return item;
	}
	return nil;
}

/* rssFolderFromId
 * Returns the RSSFolder corresponding to the specified folder ID
 * or Nil otherwise.
 */
-(RSSFolder *)rssFolderFromId:(int)folderId
{
	// Prime the cache
	if (initializedRSSArray == NO)
		[self initRSSArray];
	return [rssFeedArray objectForKey:[NSNumber numberWithInt:folderId]];
}

/* setRSSFeedLastUpdate
 * Sets the date when the RSS feed was last updated. The flushFolder function must be
 * called for the parent folder to flush this to the database.
 */
-(void)setRSSFeedLastUpdate:(int)folderId lastUpdate:(NSDate *)lastUpdate
{
	// Exit now if we're read-only
	if (readOnly)
		return;

	// Prime the cache
	if (initializedRSSArray == NO)
		[self initRSSArray];
	
	RSSFolder * folder = [rssFeedArray objectForKey:[NSNumber numberWithInt:folderId]];
	if (folder != nil)
		[folder setLastUpdate:lastUpdate];
}

/* setRSSFolderFeed
 * Change the URL of the feed on the specified RSS folder subscription.
 */
-(BOOL)setRSSFolderFeed:(int)folderId subscriptionURL:(NSString *)url
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Prime the cache
	if (initializedRSSArray == NO)
		[self initRSSArray];
	
	RSSFolder * folder = [rssFeedArray objectForKey:[NSNumber numberWithInt:folderId]];
	if (folder != nil && ![[folder subscriptionURL] isEqualToString:url])
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];

		[folder setSubscriptionURL:url];
		[self verifyThreadSafety];
		[sqlDatabase performQueryWithFormat:@"update rss_feeds set feed_url='%@' where folder_id=%d", preparedURL, folderId];
	}
	return YES;
}

/* addRSSFolder
 * Add an RSS Feed folder and return the ID of the new folder. One distinction is that
 * RSS folder names need not be unique within the parent
 */
-(int)addRSSFolder:(NSString *)feedName subscriptionURL:(NSString *)url
{
	int parentId = [self rssNodeID];
	if (parentId == -1)
		return -1;
	
	// Add the feed URL to the RSS feed table
	int folderId = [self addFolder:parentId folderName:feedName permissions:MA_RSS_Folder mustBeUnique:NO];
	if (folderId != -1)
	{
		NSString * preparedURL = [SQLDatabase prepareStringForQuery:url];
		
		// For new folders, last update is set to before now
		NSDate * lastUpdate = [NSDate distantPast];
		NSTimeInterval interval = [lastUpdate timeIntervalSince1970];

		[self verifyThreadSafety];
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"insert into rss_feeds (folder_id, feed_url, last_update) values(%d, '%@', %f)", folderId, preparedURL, interval];
		if (!results)
			return -1;

		// Add this new folder to our internal cache
		Folder * folder = [self folderFromID:folderId];
		RSSFolder * itemPtr = [[[RSSFolder alloc] initWithId:folder subscriptionURL:url update:lastUpdate] autorelease];
		[rssFeedArray setObject:itemPtr forKey:[NSNumber numberWithInt:folderId]];
		// static analyser complains
		// [results release];
	}
	return folderId;
}

/* addFolder
 * Create a new folder under the specified parent and give it the requested name and permissions.
 */
-(int)addFolder:(int)parentId folderName:(NSString *)name permissions:(int)permissions mustBeUnique:(BOOL)mustBeUnique
{
	Folder * itemPtr = nil;

	// Prime the cache
	[self initFolderArray];

	// Exit now if we're read-only
	if (readOnly)
		return -1;

	// If the folder must be unique within the specified parent, then check for its
	// existence by name and if found, return its existing ID.
	if (mustBeUnique)
	{
		itemPtr = [self folderFromIDAndName:parentId name:name];
		if (itemPtr)
			return [itemPtr itemId];
	}

	// Here we create the folder anew.
	NSString * preparedName = [SQLDatabase prepareStringForQuery:name];
	int newItemId;

	// OK, it's not in the database so create it. Then cache the ID so that we don't
	// need to hit the database next time.
	[self verifyThreadSafety];
	SQLResult * results = [sqlDatabase performQueryWithFormat:
		@"insert into folders (foldername, parent_id, unread_count, priority_unread_count, permissions) values('%@', %d, 0, 0, %d)",
						preparedName,
						parentId,
						permissions];
	if (!results)
		return -1;

	// Quick way of getting the last autoincrement primary key value (the folder_id).
	newItemId = [sqlDatabase lastInsertRowId];

	// Add this new folder to our internal cache
	itemPtr = [[[Folder alloc] initWithId:newItemId parentId:parentId name:name permissions:permissions] autorelease];
	[foldersArray setObject:itemPtr forKey:[NSNumber numberWithInt:newItemId]];

	// Send a notification when new folders are added
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderAdded" object:itemPtr];
	// static analyser complains
	// [results release];
	return [itemPtr itemId];
}

/* conferenceNodeID;
 * Returns the ID of the conference node.
 */
-(int)conferenceNodeID
{
	return MA_Conference_NodeID;
}

/* rssNodeID
 * Returns the ID of the RSS folder node
 */
-(int)rssNodeID
{
	if (cachedRSSNodeID == -1)
		cachedRSSNodeID = [self topLevelFolderByName:@"RSS Subscriptions"];
	return cachedRSSNodeID;
}

/* topLevelFolderByName
 * Returns the ID of a top level folder (a folder under root) given its
 * unique name.
 */
-(int)topLevelFolderByName:(NSString *)wantedName
{
	NSEnumerator * enumerator = [foldersArray objectEnumerator];
	Folder * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([item parentId] == -1 && [[item name] isEqualToString:wantedName])
			break;
	}
	return [item itemId];
}

/* wrappedDeleteFolder
 * Delete the specified folder. This function should be called from within a
 * transaction wrapper since it can be very SQL intensive.
 */
-(BOOL)wrappedDeleteFolder:(int)folderId
{
	NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
	NSEnumerator * enumerator = [arrayOfChildFolders objectEnumerator];
	Folder * folder;

	// Recurse and delete child folders
	while ((folder = [enumerator nextObject]) != nil)
		[self wrappedDeleteFolder:[folder itemId]];

	// Adjust unread and priority unread counts on parents
	folder = [self folderFromID:folderId];
	int adjustment = -[folder unreadCount];
	while ([folder parentId] != -1)
	{
		folder = [self folderFromID:[folder parentId]];
		[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
	}

	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	// Delete all messages in this folder then delete ourselves.
	folder = [self folderFromID:folderId];
	countOfPriorityUnread -= [folder priorityUnreadCount];
	if (IsSearchFolder(folder))
		[self executeSQLWithFormat:@"delete from search_folders where folder_id=%d", folderId];

	// If this is an RSS feed, delete from the feeds
	if (IsRSSFolder(folder))
	{
		[self executeSQLWithFormat:@"delete from rss_feeds where folder_id=%d", folderId];
		[rssFeedArray removeObjectForKey:[NSNumber numberWithInt:folderId]];
	}

	// For a search folder, the next line is a no-op but it helpfully takes care of the case where a
	// normal folder had it's permissions grobbed to MA_Search_Folder.
	[self executeSQLWithFormat:@"delete from messages where folder_id=%d", folderId];
	[self executeSQLWithFormat:@"delete from folders where folder_id=%d", folderId];
	[self executeSQLWithFormat:@"delete from folder_descriptions where folder_id=%d", folderId];

	// Send a notification when the folder is deleted
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderDeleted" object:[NSNumber numberWithInt:folderId]];

	// Remove from the folders array. Do this after we send the notification
	// so that the notification handlers don't fail if they try to dereference the
	// folder.
	[foldersArray removeObjectForKey:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* deleteFolder
 * Delete the specified folder. If the folder has any children, delete them too. Also delete
 * all messages associated with the folder. Then send a notification that the folder went bye-bye.
 */
-(BOOL)deleteFolder:(int)folderId
{
	BOOL result;

	// Exit now if we're read-only
	if (readOnly)
		return NO;

	[self beginTransaction];
	result = [self wrappedDeleteFolder:folderId];
	[self commitTransaction];
	return result;
}

/* setFolderName
 * Renames the specified folder.
 */
-(BOOL)setFolderName:(int)folderId newName:(NSString *)newName
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;

	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the name hasn't changed. Otherwise it is wasted
	// effort, basically.
	if (![[folder name] isEqualToString:newName])
	{
		[folder setName:newName];

		// Rename in the database
		[self verifyThreadSafety];
		NSString * preparedNewName = [SQLDatabase prepareStringForQuery:newName];
		[self executeSQLWithFormat:@"update folders set foldername='%@' where folder_id=%d", preparedNewName, folderId];

		// Send a notification that the folder has changed. It is the responsibility of the
		// notifiee that they work out that the name is the part that has changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	}
	return YES;
}

/* setFolderDescription
 * Sets the folder description both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderDescription:(int)folderId newDescription:(NSString *)newDescription
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;
	
	// Do nothing if the description hasn't changed. Otherwise it is wasted
	// effort, basically.
	if (![[folder description] isEqualToString:newDescription])
	{
		BOOL hadDescription = [folder hasDescription];
		[folder setDescription:newDescription];
		
		// Add a new description or update the one we have
		[self verifyThreadSafety];
		NSString * preparedNewDescription = [SQLDatabase prepareStringForQuery:newDescription];
		if (hadDescription)
			[self executeSQLWithFormat:@"update folder_descriptions set description='%@' where folder_id=%d", preparedNewDescription, folderId];
		else
			[self executeSQLWithFormat:@"insert into folder_descriptions (folder_id, description, link) values (%d, '%@', '')", folderId, preparedNewDescription];

		// Send a notification that the folder has changed. It is the responsibility of the
		// notifiee that they work out that the description is the part that has changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	}
	return YES;
}

/* setFolderLink
 * Sets the folder's associated URL link in both in the internal structure and in the folder_description table.
 */
-(BOOL)setFolderLink:(int)folderId newLink:(NSString *)newLink
{
	// Exit now if we're read-only
	if (readOnly)
		return NO;
	
	// Find our folder element.
	Folder * folder = [self folderFromID:folderId];
	if (!folder)
		return NO;

	// Do nothing if the link hasn't changed. Otherwise it is wasted
	// effort, basically.
	if (![[folder link] isEqualToString:newLink])
	{
		BOOL hadDescription = [folder hasDescription];
		[folder setLink:newLink];
		
		// Add a new link or update the one we have
		[self verifyThreadSafety];
		NSString * preparedNewLink = [SQLDatabase prepareStringForQuery:newLink];
		if (hadDescription)
			[self executeSQLWithFormat:@"update folder_descriptions set link='%@' where folder_id=%d", preparedNewLink, folderId];
		else
			[self executeSQLWithFormat:@"insert into folder_descriptions (folder_id, description, link) values (%d, '', '%@')", folderId, preparedNewLink];
		
		// Send a notification that the folder has changed. It is the responsibility of the
		// notifiee that they work out that the link is the part that has changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	}
	return YES;
}

/* folderFromID
 * Retrieve a Folder given it's ID.
 */
-(Folder *)folderFromID:(int)wantedId
{
	return [foldersArray objectForKey:[NSNumber numberWithInt:wantedId]];
}

/* folderFromIDAndName
 * Retrieve a Folder given it's parent ID and its own name.
 */
-(Folder *)folderFromIDAndName:(int)wantedParentId name:(NSString *)wantedName
{
	NSEnumerator * enumerator = [foldersArray objectEnumerator];
	Folder * item;
	
	while ((item = [enumerator nextObject]) != nil)
	{
		if ([item parentId] == wantedParentId && [[item name] isEqualToString:wantedName])
			break;
	}
	return item;
}

/* folderPathName
 * Returns the full path of the specified folder.
 */
-(NSString *)folderPathName:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	
	// Handle invalid folder ID
	if (folder == nil)
		return @"";

	// For well known nodes, use the node name
	if ([folder parentId] == -1)
		return [folder name];

	// For others, build up the path
	return [self folderPathNameHelper:folder];
}

/* folderPathNameHelper
 * A helper function for folderPathName that recurses to get the full folder
 * path back up to the root.
 */
-(NSString *)folderPathNameHelper:(Folder *)folder
{
	if ([folder parentId] == -1)
		return [folder name];
	Folder * parentFolder = [self folderFromID:[folder parentId]];
	if ([parentFolder itemId] == [self conferenceNodeID])
		return [folder name];
	if ([parentFolder itemId] == [self rssNodeID])
		return [folder name];
	return [NSString stringWithFormat:@"%@/%@", [self folderPathNameHelper:parentFolder], [folder name]];
}

/* countOfPriorityUnread
 * Returns the total number of unread priority messages.
 */
-(int)countOfPriorityUnread
{
	return countOfPriorityUnread;
}

/* addMessageToFolder
 * A counterpart to addMessage but which takes a folder path and creates
 * the folders as needed.
 */
-(int)addMessageToFolder:(int)folderId path:(NSString *)path message:(VMessage *)message raw:(BOOL)raw wasNew:(BOOL *)wasNew;
{
	// Parse off the folder path
	folderId = [self addFolderByPath:folderId path:path];
	
	// Now call addMessage to do the rest
	[message setFolderId:folderId];

	// If we're being asked to adjust the message flags based on its status then
	// do this now.
	if (!raw)
	{
		BOOL priorityFlag = [[message sender] isEqualToString:username];
		if ([message comment])
		{
			Folder * folder = [self folderFromID:folderId];
			[self initMessageArray:folder];			
			VMessage * parentMessage = [folder messageFromID:[message comment]];
			if (!priorityFlag)
				priorityFlag = [parentMessage isPriority];
			if ([parentMessage isIgnored])
			{
				[message markIgnored:YES];
				[message markRead:YES];
			}
		}
		[message markPriority:priorityFlag];	
	}
	return [self addMessage:folderId message:message wasNew:wasNew];
}

// Return the name of the folder where the metadata file is kept. These
// are divided by (vienna) folder numbers to avoid large, slow directory searches.
-(NSString *)createSpotlightFolder:(int)folderId message:(int)messageId
{
	NSString *shortCachePath = @"~/Library/Caches/Metadata/Vienna/";
	NSString *cachePath = [shortCachePath stringByExpandingTildeInPath];
	NSString *folderCachePath;
	
	[[NSFileManager defaultManager] createDirectoryAtPath: cachePath attributes: nil];

	folderCachePath = [NSString stringWithFormat: @"%@/%04d", cachePath, folderId];
	[[NSFileManager defaultManager] createDirectoryAtPath: folderCachePath attributes: nil];

	return folderCachePath;
}

-(void)addSpotlightMetadata:(int)messageId folder:(int)folderId sender:(NSString *)senderName date:(NSDate *)date text:(NSString *)text
{
	NSString *folderPath = [self createSpotlightFolder: folderId message: messageId];

	Folder *folder = [self folderFromID: folderId];
    Folder *parentFolder = [self folderFromID: [folder parentId]];	
	NSString *cixURL = [NSString stringWithFormat: @"cix:%@/%@:%d", [parentFolder name], [folder name], messageId];
	NSString *displayName = [NSString stringWithFormat: @"%@ %@", cixURL, senderName];

	// Only do this for CiX messages. Not much point
	// in indexing RSS (is there ??)
	if ([parentFolder parentId] != MA_Conference_NodeID)
		return;

	NSDictionary *attribsDict;
	attribsDict = [NSDictionary dictionaryWithObjectsAndKeys:	
		displayName, @"kMDItemDisplayName", 
		@"Vienna URL", @"kMDItemKind",
		cixURL, @"kMDItemPath",
		cixURL, @"kMDItemURL",
		cixURL, @"URL", // This is the one Finder uses.
		text, @"kMDItemTextContent",
		date, @"kMDItemContentModificationDate",
		date, @"kMDItemContentCreationDate",
		date, @"kMDItemLastUsedDate",
		[NSArray arrayWithObjects: senderName, nil], @"kMDItemAuthors",
		nil, nil];

	NSString *mdFilename = [NSString stringWithFormat: @"%@/%06d.cixurl", folderPath, messageId];
	[attribsDict writeToFile: mdFilename atomically: YES];
	
	// Make it a finder-openable URL file, and fake the creation date.
	NSNumber *creatorCode = [NSNumber numberWithUnsignedLong:'MACS'];
	NSNumber *typeCode = [NSNumber numberWithUnsignedLong:'ilht'];
	NSDictionary *fileAttr = [NSDictionary dictionaryWithObjectsAndKeys:
		creatorCode, NSFileHFSCreatorCode,
		typeCode, NSFileHFSTypeCode,
		date, NSFileCreationDate,
		date, NSFileModificationDate,
		nil, nil];
	[[NSFileManager defaultManager] changeFileAttributes: fileAttr atPath: mdFilename];
}

-(void)removeSpotlightMetadata:(int)messageId folder:(int)folderId
{
	NSString *folderPath = [self createSpotlightFolder: folderId message: messageId];
	NSString *mdFilename = [NSString stringWithFormat: @"%@/%06d.cixurl", folderPath, messageId];
	
	[[NSFileManager defaultManager] removeFileAtPath: mdFilename handler:nil];
}

/* addMessage
 * Adds or updates a message in the specified folder. Returns the number of the
 * message that was added or updated or -1 if we couldn't add the message for
 * some reason.
 */
-(int)addMessage:(int)folderID message:(VMessage *)message wasNew:(BOOL *)wasNew
{
	// Exit now if we're read-only
	if (readOnly)
		return -1;

	// In case we have an error...
	if (wasNew != nil)
		*wasNew = NO;

	// Make sure the folder ID is valid. We need it to decipher
	// some info before we add the message.
	Folder * folder = [self folderFromID:folderID];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		// Folder permissions cannot be MA_Empty_Folder
		if ([folder permissions] == MA_Empty_Folder)
			return -1;

		// Extract the message data from the dictionary.
		NSString * messageText = [[message messageData] objectForKey:MA_Column_MessageText];
		NSString * messageTitle = [[message messageData] objectForKey:MA_Column_MessageTitle]; 
		NSDate * messageDate = [[message messageData] objectForKey:MA_Column_MessageDate];
		NSString * userName = [[message messageData] objectForKey:MA_Column_MessageFrom];
		int messageNumber = [message messageId];
		int commentNumber = [message comment];
		BOOL marked_flag = [message isFlagged];
		BOOL read_flag = [message isRead];
		BOOL priority_flag = [message isPriority];
		BOOL ignored_flag = [message isIgnored];

		// Set some defaults
		if (messageDate == nil)
			messageDate = [NSDate date];
		if (userName == nil)
			userName = @"";

		// Parse off the title
		if (messageTitle == nil || [messageTitle isEqualToString:@""])
			messageTitle = [messageText firstNonBlankLine];

		// Save date as time intervals
		NSTimeInterval interval = [messageDate timeIntervalSince1970];

		// Unread count adjustment factor
		int adjustment = 0;
		
		// Fix title and message body so they're acceptable to SQL
		NSString * preparedMessageTitle = [SQLDatabase prepareStringForQuery:messageTitle];
		NSString * preparedMessageText = [SQLDatabase prepareStringForQuery:messageText];
		NSString * preparedUserName = [SQLDatabase prepareStringForQuery:userName];
		NSString * preparedGuid;
		if ([message guid] != nil)
			preparedGuid = [SQLDatabase prepareStringForQuery:[message guid]];
		else
			preparedGuid = @"";

		// Verify we're on the right thread
		[self verifyThreadSafety];

		// Special case for RSS messages. These messages replace duplicates which need to be
		// identified by matching the sender and title, then the message text. We start back
		// from the most recent message for performance reasons. If we identify a duplicate
		// then we replace that duplicate otherwise we file as a new message.
		if (messageNumber == MA_MsgID_RSSNew)
		{
			NSArray * msgs = [folder messages];
			int count = [msgs count];

			messageNumber = MA_MsgID_New;
			while (--count >= 0)
			{
				VMessage * thisMessage = [msgs objectAtIndex:count];
				if ([[thisMessage title] isEqualToString:messageTitle] && [[thisMessage sender] isEqualToString:userName])
				{
					NSString * msgText = [self messageText:folderID messageId:[thisMessage messageId]];
					if ([msgText isEqualToString:messageText])
					{
						messageNumber = [thisMessage messageId];
						read_flag = [thisMessage isRead];
						break;
					}
				}
			}
		}
		
		// We know we're inserting a new message when the messagenumber
		// we have now is MA_MsgID_New.
		if (messageNumber == MA_MsgID_New)
		{
			SQLResult * results;

			results = [sqlDatabase performQueryWithFormat:
					@"insert into messages (message_id, comment_id, folder_id, sender, date, read_flag, marked_flag, priority_flag, ignored_flag, title, text, rss_guid) "
					"values((select coalesce(max(message_id)+1, 1) from messages where folder_id=%d), %d, %d, '%@', %f, %d, %d, %d, %d, '%@', '%@', '%@')",
					folderID,
					commentNumber,
					folderID,
					preparedUserName,
					interval,
					read_flag,
					marked_flag,
					priority_flag,
					ignored_flag,
					preparedMessageTitle,
					preparedMessageText,
					preparedGuid];
			if (!results)
				return -1;
			// static analyser complains
			// [results release];
			
			// Now extract the number of the message we just inserted. This is a tricky step that tries to
			// be as specific as possible to avoid potential race conditions. I regard the interval value to
			// be a reasonable choice in making this distinction. Hope I'm not wrong (!)
			results = [sqlDatabase performQueryWithFormat:@"select max(message_id) from messages where folder_id=%d", folderID, interval];
			if (results && [results rowCount])
			{
				SQLRow * row = [results rowAtIndex:0];
				messageNumber = [[row stringForColumn:@"max(message_id)"] intValue];
			}
			// analyser complains
			// [results release];

			// Add the message to the folder
			[message setNumber:messageNumber];
			[folder addMessage:message];
			
			// Update folder unread count
			if (!read_flag)
				adjustment = 1;
			if (wasNew != nil)
				*wasNew = YES;
		}
		else
		{
			// Try and update the message. If it fails then we know the message
			// isn't already in the database and we'll do an insert instead.
			VMessage * newMessage = [folder messageFromID:messageNumber];
			if (newMessage != nil)
			{
				BOOL old_read_flag = [newMessage isRead];
				SQLResult * results;
				
				results = [sqlDatabase performQueryWithFormat:@"update messages set sender='%@', date=%f, read_flag=%d, priority_flag=%d, ignored_flag=%d, "
														 "marked_flag=%d, title='%@', text='%@' where folder_id=%d and message_id=%d",
														 preparedUserName,
														 interval,
														 read_flag,
														 priority_flag,
														 ignored_flag,
														 marked_flag,
														 preparedMessageTitle,
														 preparedMessageText,
														 folderID,
														 messageNumber];
				if (!results)
					return -1;

				// If the update succeeded then we just need to fiddle
				// the read count on the folders if it changed.
				if (old_read_flag != read_flag)
					adjustment = (read_flag ? -1 : 1);
				// static analyser complains
				// [results release];
				if (wasNew != nil)
					*wasNew = NO;
			}
			else
			{
				// This is where we're inserting a message that has a known
				// message number and we know it doesn't already appear in the
				// database.
				SQLResult * results;
				results = [sqlDatabase performQueryWithFormat:
							@"insert into messages (message_id, comment_id, folder_id, sender, date, read_flag, marked_flag, priority_flag, ignored_flag, title, text) "
							"values(%d, %d, %d, '%@', %f, %d, %d, %d, %d, '%@', '%@')",
							messageNumber,
							commentNumber,
							folderID,
							preparedUserName,
							interval,
							read_flag,
							marked_flag,
							priority_flag,
							ignored_flag,
							preparedMessageTitle,
							preparedMessageText];
				if (!results)
					return -1;
				
				// Add the message to the folder
				[folder addMessage:message];
				
				// Update folder unread count
				if (!read_flag)
					adjustment = 1;
				// static analyser complians
				// [results release];
				if (wasNew != nil)
					*wasNew = YES;
			}
		}

		// Save a small file for Spotlight to index
		if ([[NSUserDefaults standardUserDefaults] boolForKey:MAPref_SaveSpotlightMetadata])
			[self addSpotlightMetadata: messageNumber folder: folderID sender:userName date: messageDate text: messageText];
		
		// Fix unread count on parent folders
		if (adjustment != 0)
		{
			if ([message isPriority])
			{
				[folder setPriorityUnreadCount:[folder priorityUnreadCount] + adjustment];
				countOfPriorityUnread += adjustment;
			}
			[folder setUnreadCount:[folder unreadCount] + adjustment];
			while ([folder parentId] != -1)
			{
				folder = [self folderFromID:[folder parentId]];
				[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
			}
		}
		return messageNumber;
	}
	return -1;
}

/* deleteMessage
 * Deletes a message from the specified folder
 */
-(BOOL)deleteMessage:(int)folderId messageNumber:(int)messageNumber
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		VMessage * message = [folder messageFromID:messageNumber];
		if (message != nil)
		{
			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"delete from messages where folder_id=%d and message_id=%d", folderId, messageNumber];
			if (results)
			{
				if (![message isRead])
				{
					if ([message isPriority])
					{
						[folder setPriorityUnreadCount:[folder priorityUnreadCount] - 1];
						countOfPriorityUnread -= 1;
					}
					[folder setUnreadCount:[folder unreadCount] - 1];
					
					// Update childUnreadCount for our parent. Since we're just working
					// on one message, we do this the faster way.
					Folder * parentFolder = folder;
					while ([parentFolder parentId] != -1)
					{
						parentFolder = [self folderFromID:[parentFolder parentId]];
						[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] - 1];
					}
				}
				[folder deleteMessage:messageNumber];
				// static analyser complains
				// [results release];
				
				// Remove associated spotlight metadata file.
				if ([[NSUserDefaults standardUserDefaults] boolForKey:MAPref_SaveSpotlightMetadata])
					[self removeSpotlightMetadata: messageNumber folder: folderId];
				return YES;
			}
		}
	}
	return NO;
}

/* flushFolder
 * Updates the unread count for a folder in the database
 */
-(void)flushFolder:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];

	if ([folder isUnreadCountChanged] && !IsSearchFolder(folder))
	{
		int unreadCount = [folder unreadCount];
		int priorityUnreadCount = [folder priorityUnreadCount];

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		[self executeSQLWithFormat:@"update folders set unread_count=%d, priority_unread_count=%d where folder_id=%d", unreadCount, priorityUnreadCount, folderId];
		[folder resetUnreadCountChanged];
		
		// If this is an RSS folder, flush the last update
		RSSFolder * rssFolder = (RSSFolder *)[rssFeedArray objectForKey:[NSNumber numberWithInt:folderId]];
		if (rssFolder != nil)
		{
			NSTimeInterval interval = [[rssFolder lastUpdate] timeIntervalSince1970];
			[self executeSQLWithFormat:@"update rss_feeds set last_update=%f where folder_id=%d", interval, folderId];
		}
	}
}

/* initTasksArray
 * Preloads all the tasks from the tasks table.
 */
-(void)initTasksArray
{
	if (!initializedTasksArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		SQLResult * results;
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from tasks order by order_code"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;

			while ((row = [enumerator nextObject]))
			{
				int taskId = [[row stringForColumn:@"task_id"] intValue];
				int orderCode = [[row stringForColumn:@"order_code"] intValue];
				int actionCode = [[row stringForColumn:@"action_code"] intValue];
				int resultCode = [[row stringForColumn:@"result_code"] intValue];
				NSString * actionData = [row stringForColumn:@"action_data"];
				NSString * folderName = [row stringForColumn:@"folder_name"];
				NSString * resultString = [row stringForColumn:@"result_data"];
				NSDate * lastRunDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"last_run"] doubleValue]];
				NSDate * earliestRunDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"earliest_run"] doubleValue]];

				// Frob MA_TaskResult_Running to MA_TaskResult_Waiting (we may have crashed
				// while executing that task).
				if (resultCode == MA_TaskResult_Running)
				{
					resultCode = MA_TaskResult_Waiting;
					earliestRunDate = [NSDate distantPast];
				}

				VTask * task = [[VTask alloc] init];
				[task setTaskId:taskId];
				[task setOrderCode:orderCode];
				[task setActionCode:actionCode];
				[task setActionData:actionData];
				[task setFolderName:folderName];
				[task setResultCode:resultCode];
				[task setResultString:resultString];
				[task setLastRunDate:lastRunDate];
				[task setEarliestRunDate:earliestRunDate];
				[tasksArray addObject:task];
				[task release];
			}
		}
		// static analsyer complains 
		// [results release];
		initializedTasksArray = YES;
	}
}

/* arrayOfTasks
 * Returns an NSArray of all tasks in the database
 */
-(NSArray *)arrayOfTasks:(BOOL)onlyReadyTasks
{
	// Prime the cache
	if (initializedTasksArray == NO)
		[self initTasksArray];

	// Return those elements that are ready to execute
	NSMutableArray * newArray = [NSMutableArray array];
	NSEnumerator * enumerator = [tasksArray objectEnumerator];
	VTask * task;
	
	while ((task = [enumerator nextObject]) != nil)
	{
		if (!onlyReadyTasks || (onlyReadyTasks && [task resultCode] == MA_TaskResult_Waiting && [[task earliestRunDate] compare:[NSDate date]] == NSOrderedAscending))
			[newArray addObject:task];
	}

	// Sort the array by order code.
	return [newArray sortedArrayUsingSelector:@selector(taskCompare:)];
}

/* findTask
 * Locates an existing task in the array of tasks that match the requested action code and data.
 */
-(VTask *)findTask:(int)wantedActionCode wantedActionData:(NSString *)wantedActionData
{
	// Prime the cache
	if (initializedTasksArray == NO)
		[self initTasksArray];
	
	int index;
	for (index = 0; index < (int)[tasksArray count]; ++index)
	{
		VTask * theTask = [tasksArray objectAtIndex:index];
		if ([theTask actionCode] == wantedActionCode && [[theTask actionData] isEqualToString:wantedActionData])
			return theTask;
	}
	return nil;
}

/* clearTasks
 * Remove tasks with the specified flag from the tasks list.
 */
-(void)clearTasks:(int)resultCode;
{
	// Exit now if we're read-only
	if (readOnly)
		return;

	int index;
	for (index = [tasksArray count] - 1; index >= 0; --index)
	{
		if ([[tasksArray objectAtIndex:index] resultCode] == resultCode)
			[tasksArray removeObjectAtIndex:index];
	}

	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	[self executeSQLWithFormat:@"delete from tasks where result_code=%d", resultCode];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TaskDeleted" object:nil];
}

/* setTaskCompleted
 * Called when a task has completed and sets the result code, data and last run date
 */
-(void)setTaskCompleted:(VTask *)task
{
	[task setEarliestRunDate:[NSDate distantFuture]];
	[task setLastRunDate:[NSDate date]];
	[self updateTask:task];
}

/* setTaskWaiting
 * Mark a task pending to be executed on the next connection.
 */
-(void)setTaskWaiting:(VTask *)task
{
	[task setEarliestRunDate:[NSDate distantPast]];
	[task setResultCode:MA_TaskResult_Waiting];
	[self updateTask:task];
}

/* setTaskRunning
 * Mark a task as being executed at this present time.
 */
-(void)setTaskRunning:(VTask *)task
{
	[task setResultCode:MA_TaskResult_Running];
	[self updateTask:task];
}

/* updateTask
 * Call this function to commit changes to a task to the database.
 */
-(void)updateTask:(VTask *)task
{
	// Exit now if we're read-only
	if (readOnly)
		return;
	
	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	// Update the database
	NSTimeInterval lastRunInterval = [[task lastRunDate] timeIntervalSince1970];
	NSTimeInterval earliestRunInterval = [[task earliestRunDate] timeIntervalSince1970];
	SQLResult * result = [sqlDatabase performQueryWithFormat:@"update tasks set result_code=%d, result_data='%@', last_run=%f, earliest_run=%f where task_id=%d",
			[task resultCode],
			[task resultString],
			lastRunInterval,
			earliestRunInterval,
			[task taskId]];
	if (!result)
		return;

	// Notify all interested parties
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TaskChanged" object:task];
	// static analyser ccomplains
	// [result release];
}

/* addTask
 * Add a task to the Tasks list. 
 */
-(VTask *)addTask:(int)actionCode actionData:(NSString *)actionData folderName:(NSString *)folderName orderCode:(int)orderCode
{
	NSAssert(actionData != nil, @"actionData cannot be nil. Use an empty string instead");
	NSAssert(folderName != nil, @"folderName cannot be nil. Use an empty string instead");

	// Add to our internal tasks array
	VTask * task = [[[VTask alloc] init] autorelease];
	[task setOrderCode:orderCode];
	[task setActionCode:actionCode];
	[task setActionData:actionData];
	[task setFolderName:folderName];
	return [self addTask:task];
}

/* addTask
 * Add a task to the Tasks list using a pre-filled task object.
 */
-(VTask *)addTask:(VTask *)task
{
	// Make sure we're initialised
	[self initTasksArray];
	
	// Exit now if we're read-only
	if (readOnly)
		return nil;
	
	// Look for an existing task with the action code. And, while we're
	// at it, find the before code so we set insertIndex appropriately
	// if we need to insert anything.
	NSEnumerator * enumerator = [tasksArray objectEnumerator];
	int insertIndex = [tasksArray count];
	int itemIndex = 0;
	VTask * theTask;

	while ((theTask = [enumerator nextObject]) != nil)
	{
		if ([theTask compareForUniqueness:task])
		{
			// Prime this task to run again
			if ([theTask resultCode] != MA_TaskResult_Running)
			{
				[theTask setResultCode:MA_TaskResult_Waiting];
				[theTask setEarliestRunDate:[NSDate distantPast]];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TaskChanged" object:theTask];
			}
			return theTask;
		}
		if ([theTask orderCode] > [task orderCode])
			insertIndex = itemIndex;
		++itemIndex;
	}

	if ([task actionData] == nil)
		[task setActionData:@""];
	if ([task folderName] == nil)
		[task setFolderName:@""];
	NSString * preparedActionData = [SQLDatabase prepareStringForQuery:[task actionData]];
	NSString * preparedFolderName = [SQLDatabase prepareStringForQuery:[task folderName]];

	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	// OK, it's not in the database so create it. Then cache the ID so that we don't
	// need to hit the database next time.
	NSTimeInterval lastRunInterval = [[task lastRunDate] timeIntervalSince1970];
	NSTimeInterval earliestRunInterval = [[task earliestRunDate] timeIntervalSince1970];
	SQLResult * results = [sqlDatabase performQueryWithFormat:
		@"insert into tasks (order_code, action_code, action_data, folder_name, result_code, result_data, last_run, earliest_run) values(%d, %d, '%@', '%@', %d, '%@', %f, %f)",
												[task orderCode],
												[task actionCode],
												preparedActionData,
												preparedFolderName,
												[task resultCode],
												[task resultString],
												lastRunInterval,
												earliestRunInterval];
	if (!results)
		return nil;
	
	// Quick way of getting the last autoincrement primary key value (the task_id).
	int newTaskId = [sqlDatabase lastInsertRowId];
	[task setTaskId:newTaskId];
	[tasksArray insertObject:task atIndex:insertIndex];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TaskAdded" object:task];
	// static analyser complains
	// [results release];
	return task;
}

/* deleteTask
 * Delete the specified task from the database and from our internal cache.
 */
-(void)deleteTask:(VTask *)task
{
	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	[task retain];
	[tasksArray removeObject:task];
	[self executeSQLWithFormat:@"delete from tasks where task_id=%d", [task taskId]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_TaskDeleted" object:task];
	[task release];
}

/* initSearchFoldersArray
 * Preloads all the search folders into the searchFolder dictionary.
 */
-(void)initSearchFoldersArray
{
	if (!initializedSearchFoldersArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from search_folders"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;

			while ((row = [enumerator nextObject]))
			{
				NSString * search_string = [row stringForColumn:@"search_string"];
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				
				VCriteriaTree * criteriaTree = [[VCriteriaTree alloc] initWithString:search_string];
				[searchFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
				[criteriaTree release];
			}
		}
		// static analyser complains
		// [results release];
		initializedSearchFoldersArray = YES;
	}
}

/* searchStringForSearchFolder
 * Retrieve the search folder criteria string for the specified folderId. Returns nil if
 * folderId is not a search folder.
 */
-(VCriteriaTree *)searchStringForSearchFolder:(int)folderId
{
	[self initSearchFoldersArray];
	return [searchFoldersArray objectForKey:[NSNumber numberWithInt:folderId]];
}

/* createSearchFolder
 * Create a new search folder. If the specified folder already exists, then this is synonymous to
 * calling updateSearchFolder.
 */
-(BOOL)createSearchFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree
{
	Folder * itemPtr = [self folderFromIDAndName:-1 name:folderName];
	BOOL success = YES;

	if (itemPtr)
		[self updateSearchFolder:[itemPtr itemId] withFolder:folderName withQuery:criteriaTree];
	else
	{
		int folderId = [self addFolder:-1 folderName:folderName permissions:MA_Search_Folder mustBeUnique:YES];
		if (folderId == -1)
			success = NO;
		else
		{
			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
			[self executeSQLWithFormat:@"insert into search_folders (folder_id, search_string) values (%d, '%@')", folderId, preparedQueryString];
			[searchFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];

			NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
			[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
		}
	}
	return success;
}

/* updateSearchFolder
 * Updates the search string for the specified folder.
 */
-(BOOL)updateSearchFolder:(int)folderId withFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree
{
	Folder * folder = [self folderFromID:folderId];
	if (![[folder name] isEqualToString:folderName])
		[folder setName:folderName];
	
	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	// Update the search folder string
	NSString * preparedQueryString = [SQLDatabase prepareStringForQuery:[criteriaTree string]];
	[self executeSQLWithFormat:@"update search_folders set search_string='%@' where folder_id=%d", preparedQueryString, folderId];
	[searchFoldersArray setObject:criteriaTree forKey:[NSNumber numberWithInt:folderId]];
	
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:folderId]];
	return YES;
}

/* initFolderArray
 * Initializes the folder array if necessary.
 */
-(void)initFolderArray
{
	if (!initializedFoldersArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");
		
		// We'll be keeping a running count of all priority unread messages
		countOfPriorityUnread = 0;
		
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from folders order by folder_id"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				NSString * name = [row stringForColumn:@"foldername"];
				int newItemId = [[row stringForColumn:@"folder_id"] intValue];
				int newParentId = [[row stringForColumn:@"parent_id"] intValue];
				int unreadCount = [[row stringForColumn:@"unread_count"] intValue];
				int priorityUnreadCount = [[row stringForColumn:@"priority_unread_count"] intValue];
				int permissions = [[row stringForColumn:@"permissions"] intValue];
				
				// This code has a potential bug.
				// We assume that the parent folder id always gets returned ahead of the
				// folder id in the result set. Up to now this has always been true. But
				// potentially this can fail. If this happens then the fix is to spin off
				// the setChildUnreadCount computation to a separate loop. The NSAssert will
				// fire to warn us when this can happen.
				//
				Folder * folder = [[[Folder alloc] initWithId:newItemId parentId:newParentId name:name permissions:permissions] autorelease];
				if (IsSearchFolder(folder))
				{
					unreadCount = 0;
					priorityUnreadCount = 0;
				}
				[folder setUnreadCount:unreadCount];
				[folder setPriorityUnreadCount:priorityUnreadCount];
				if (priorityUnreadCount > 0)
					countOfPriorityUnread += priorityUnreadCount;
				if (newParentId != -1 && unreadCount > 0)
				{
					Folder * parentFolder = [self folderFromID:newParentId];
					NSAssert(parentFolder, @"Something has broken. The parent folder for a folder was not found");
					while (parentFolder != nil)
					{
						[parentFolder setChildUnreadCount:[parentFolder childUnreadCount] + unreadCount];
						parentFolder = [self folderFromID:[parentFolder parentId]];
					}
				}
				[foldersArray setObject:folder forKey:[NSNumber numberWithInt:newItemId]];
			}
		}
		// static analyser complains 
		// [results release];

		// Load descriptions and assign to each folder.
		results = [sqlDatabase performQuery:@"select folder_id, description, link from folder_descriptions"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				NSString * descriptiontext = [row stringForColumn:@"description"];
				NSString * linktext = [row stringForColumn:@"link"];
				Folder * folder = [self folderFromID:folderId];
				[folder setDescription:descriptiontext];
				[folder setLink:linktext];
			}
		}
		// static analyser complains
		// [results release];

		// Done
		initializedFoldersArray = YES;
	}
}

/* arrayOfFolders
 * Returns an NSArray of all folders with the specified parent.
 */
-(NSArray *)arrayOfFolders:(int)parentId
{
	// Prime the cache
	if (initializedFoldersArray == NO)
		[self initFolderArray];
	
	NSMutableArray * newArray = [NSMutableArray array];
	if (newArray != nil)
	{
		NSEnumerator * enumerator = [foldersArray objectEnumerator];
		Folder * item;
		
		while ((item = [enumerator nextObject]) != nil)
		{
			if ([item parentId] == parentId)
				[newArray addObject:item];
		}
	}
	return (parentId == -1) ? newArray : [newArray sortedArrayUsingSelector:@selector(folderCompare:)];
}

/* initPersonArray
 * Initializes the person array if necessary.
 */
-(void)initPersonArray
{
	if (!initializedPersonArray)
	{
		// Make sure we have a database.
		NSAssert(sqlDatabase, @"Database not assigned for this item");

		SQLResult * results;
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQuery:@"select * from people"];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				NSString * name = [row stringForColumn:@"name"];
				NSString * info = [row stringForColumn:@"info"];
				int personId = [[row stringForColumn:@"person_id"] intValue];

				VPerson * person = [[VPerson alloc] init];
				[person setPersonId:personId];
				[person setShortName:name];
				[person setName:name];
				[person setInfo:info];
				[personArray setObject:person forKey:name];
				[person release];
			}
		}
		// static analyser complains
		// [results release];
		initializedPersonArray = YES;
	}
}

/* retrievePerson
 * Retrieve an entry for the specified person from the People table
 */
-(VPerson *)retrievePerson:(NSString *)name
{
	[self initPersonArray];
	return [personArray objectForKey:name];
}

/* updatePerson
 * Update an entry in the People table.
 */
-(void)updatePerson:(NSString *)name data:(NSString *)data
{
	// Prime the cache
	[self initPersonArray];

	NSString * preparedName = [SQLDatabase prepareStringForQuery:name];
	NSString * preparedData = [SQLDatabase prepareStringForQuery:data];
	
	// Verify we're on the right thread
	[self verifyThreadSafety];

	// Find the person in the cache. If the person is missing then we
	// need to add a new record. Otherwise we update the existing record.
	VPerson * person = [personArray objectForKey:name];
	SQLResult * results;
	if (person != nil)
	{
		results = [sqlDatabase performQueryWithFormat:@"update people set info='%@' where name='%@'", preparedData, preparedName];
		[person setInfo:data];
	}
	else
	{
		results = [sqlDatabase performQueryWithFormat:@"insert into people (name, info) values ('%@', '%@')", preparedName, preparedData];
		person = [[VPerson alloc] init];
		[person setShortName:name];
		[person setName:name];
		[person setInfo:data];
		[person setPersonId:[sqlDatabase lastInsertRowId]];
		[personArray setObject:person forKey:name];
		[person autorelease];
	}
	
	// Send a notification when new folders are added
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PersonUpdated" object:person];
	// static analyser complains
	// [results release];
}

/* findMessages
 * Searches the messages table for messages that match a specific criteria.
 */
-(NSArray *)findMessages:(NSDictionary *)criteriaDictionary
{
	NSArray * criteriaColumns = [self arrayOfFields];
	NSEnumerator * enumerator = [criteriaColumns objectEnumerator];
	VField * column;

	// We build up one big SQL condition string based on the
	// information requested in the dictionary.
	NSString * sqlConditionList = @"";
	int numberOfClauses = 0;

	while ((column = [enumerator nextObject]) != nil)
	{
		NSArray * folderList = [criteriaDictionary objectForKey:[column name]];
		if (folderList != nil)
		{
			if (numberOfClauses > 0)
				sqlConditionList = [NSString stringWithFormat:@"%@ and ", sqlConditionList];
			
			NSEnumerator * enumerator = [folderList objectEnumerator];
			NSString * sqlPart = @"";
			NSString * value;
			int countOfItems = 0;

			while ((value = [enumerator nextObject]) != nil)
			{
				if (countOfItems > 0)
					sqlPart = [NSString stringWithFormat:@"%@ or ", sqlPart];
				sqlPart = [NSString stringWithFormat:@"%@%@='%@'", sqlPart, [column sqlField], value];
				++countOfItems;
			}
			if (countOfItems > 1)
				sqlPart = [NSString stringWithFormat:@"(%@)", sqlPart];
			
			sqlConditionList = [NSString stringWithFormat:@"%@%@", sqlConditionList, sqlPart];
			++numberOfClauses;
		}
	}

	NSMutableArray * messageArray = [[NSMutableArray alloc] init];
	if (numberOfClauses)
	{
		SQLResult * results;

		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQueryWithFormat:@"select * from messages where %@", sqlConditionList];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			SQLRow * row;
			
			while ((row = [enumerator nextObject]))
			{
				int messageId = [[row stringForColumn:@"message_id"] intValue];
				int folderId = [[row stringForColumn:@"folder_id"] intValue];
				int commentId = [[row stringForColumn:@"comment_id"] intValue];
				NSString * title = [row stringForColumn:@"title"];
				NSString * senderName = [row stringForColumn:@"sender"];
				NSString * guid = [row stringForColumn:@"sender"];
				NSDate * messageDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"date"] doubleValue]];

				VMessage * message = [[VMessage alloc] initWithInfo:messageId];
				[message setFolderId:folderId];
				[message setComment:commentId];
				[message setSender:senderName];
				[message setTitle:title];
				[message setGuid:guid];
				[message setDateFromDate:messageDate];
				[messageArray addObject:message];
				[message release];
			}
		}
		// static analyser complains
		// [results release];
	}
	return messageArray;
}

/* initMessageArray
 * Ensures that the specified folder has a minimal cache of message information. This is just
 * the message id, read flag and the priority flag.
 */
-(BOOL)initMessageArray:(Folder *)folder
{
	// Prime the folder cache
	[self initFolderArray];

	// Exit now if we're already initialized
	if ([folder messageCount] == -1)
	{
		int folderId = [folder itemId];
		SQLResult * results;

		// Initialize to indicate that the folder array is valid.
		[folder markFolderEmpty];
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		results = [sqlDatabase performQueryWithFormat:@"select message_id, title, sender, read_flag, ignored_flag, priority_flag from messages where folder_id=%d", folderId];
		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			int unread_count = 0;
			int priority_unread_count = 0;
			SQLRow * row;

			while ((row = [enumerator nextObject]) != nil)
			{
				int messageId = [[row stringForColumn:@"message_id"] intValue];
				BOOL read_flag = [[row stringForColumn:@"read_flag"] intValue];
				BOOL priority_flag = [[row stringForColumn:@"priority_flag"] intValue];
				BOOL ignored_flag = [[row stringForColumn:@"ignored_flag"] intValue];
				NSString * title = [row stringForColumn:@"title"];
				NSString * sender = [row stringForColumn:@"sender"];

				// Keep our own track of unread messages
				if (!read_flag)
				{
					if (priority_flag)
						++priority_unread_count;
					++unread_count;
				}
				
				VMessage * message = [[VMessage alloc] initWithInfo:messageId];
				[message markRead:read_flag];
				[message markPriority:priority_flag];
				[message markIgnored:ignored_flag];
				[message setFolderId:folderId];
				[message setTitle:title];
				[message setSender:sender];
				[folder addMessage:message];
				[message release];
			}

			// This is a good time to do a quick check to ensure that our
			// own count of unread is in sync with the folders count and fix
			// them if not.
			if (unread_count != [folder unreadCount])
			{
				NSLog(@"Fixing unread count for %@ (%d on folder versus %d in messages) for folder_id %d, parent %d",
					  [folder name], [folder unreadCount], unread_count, [folder itemId], [folder parentId] );
				[self setFolderUnreadCount:folder adjustment:(unread_count - [folder unreadCount])];
				[self flushFolder:folderId];
			}
			if (priority_unread_count != [folder priorityUnreadCount])
			{
				NSLog(@"Fixing priority unread count for %@ (%d on folder versus %d in messages) for folder_id %d, parent %d",
					  [folder name], [folder priorityUnreadCount], priority_unread_count, [folder itemId], [folder parentId]);
				countOfPriorityUnread += priority_unread_count - [folder priorityUnreadCount];
				[folder setPriorityUnreadCount:priority_unread_count];
				[self flushFolder:folderId];
			}
		}
		// analyser complains
		// [results release];
	}
	return YES;
}

/* releaseMessages
 * Free up the memory used to cache copies of the messages in the specified folder.
 */
-(void)releaseMessages:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	[folder clearMessages];
}

/* arrayOfChildMessages
 * Returns the specified message and all messages that are child messages.
 */
-(NSArray *)arrayOfChildMessages:(int)folderId messageId:(int)messageId
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray array];

	if (folder != nil)
	{
		// Make sure we've cached the list of all messages
		// in the specified folder.
		[self initMessageArray:folder];
		
		// Always add ourselves.
		[newArray addObject:[folder messageFromID:messageId]];
		
		// Now we want all messages where [Message comment] is our message ID. Then
		// recurse and get the IDs for all subsequent messages.
		[self buildArrayOfChildMessages:newArray folder:folder messageId:messageId searchIndex:0];
	}
	return newArray;
}

/* buildArrayOfChildMessages
 * This is the recursive function that searches the folders' cached message array to build a list
 * of child messages for the specified message. It is SLOW. This is the sort of code that really needs
 * to be replaced by maintaining a proper set of parent index pointers on every message.
 */
-(void)buildArrayOfChildMessages:(NSMutableArray *)newArray folder:(Folder *)folder messageId:(int)messageId searchIndex:(unsigned int)searchIndex
{
	NSArray * messagesArray = [folder messages];
	BOOL isSorted = YES;
	int largestID = 0;

	while (searchIndex < [messagesArray count])
	{
		VMessage * message = [messagesArray objectAtIndex:searchIndex];
		if ([message messageId] < largestID)
			isSorted = NO;
		if ([message comment] == messageId)
		{
			[newArray addObject:message];
			[self buildArrayOfChildMessages:newArray folder:folder messageId:[message messageId] searchIndex:(isSorted ? searchIndex+1 : 0)];
		}
		largestID = [message messageId];
		++searchIndex;
	}
}

/* criteriaToSQL
 * Converts a criteria tree to it's SQL representative.
 */
-(NSString *)criteriaToSQL:(VCriteriaTree *)criteriaTree
{
	NSString * sqlString = @"";
	NSEnumerator * enumerator = [criteriaTree criteriaEnumerator];
	VCriteria * criteria;
	int count = 0;

	while ((criteria = [enumerator nextObject]) != nil)
	{
		VField * field = [self fieldByTitle:[criteria field]];
		NSAssert1(field != nil, @"VCriteria field %@ does not have an associated database field", [criteria field]);
		int type = [field type];

		NSString * operatorString = nil;
		NSString * valueString = nil;
		
		switch ([criteria operator])
		{
//PJC: sqlite3 doesn't like quoted integers
			case MA_CritOper_Is:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @"=%@";
				else
					operatorString = @"='%@'"; 
				break;
			case MA_CritOper_IsNot:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @"<>%@";
				else
					operatorString = @"<>'%@'"; 
				break;
			case MA_CritOper_IsLessThan:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @"<%@";
				else
					operatorString = @"<'%@'"; 
				break;
			case MA_CritOper_IsGreaterThan:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @">%@";
				else
					operatorString = @">'%@'"; 
				break;			
			case MA_CritOper_IsLessThanOrEqual:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @"<=%@";
				else
					operatorString = @"<='%@'"; 
				break;			
			case MA_CritOper_IsGreaterThanOrEqual:
				if (type == MA_FieldType_Flag || type == MA_FieldType_Integer)
					operatorString = @">=%@";
				else
					operatorString = @">='%@'"; 
				break;
			case MA_CritOper_Contains:				operatorString = @" like '%%%@%%'"; break;
			case MA_CritOper_NotContains:			operatorString = @" not like '%%%@%%'"; break;
			case MA_CritOper_IsBefore:				operatorString = @"<%@"; break;
			case MA_CritOper_IsAfter:				operatorString = @">%@"; break;
			case MA_CritOper_IsOnOrBefore:			operatorString = @"<=%@"; break;
			case MA_CritOper_IsOnOrAfter:			operatorString = @">=%@"; break;
		}

		switch ([field type])
		{
			case MA_FieldType_Flag:
				valueString = [[criteria value] isEqualToString:@"Yes"] ? @"1" : @"0";
				break;
				
			case MA_FieldType_Folder:
				// The value is a path, so we need to convert a path to a Folder *
				break;
				
			case MA_FieldType_Date: {
				if ([criteria operator] == MA_CritOper_Is)
				{
					// Special case for Date is <date> because the resolution of the date field is in
					// milliseconds. So we need to translate this to a range for this to make sense.
					NSCalendarDate * startDate = [NSCalendarDate dateWithString:[criteria value] calendarFormat:@"%d/%m/%y"];
					NSCalendarDate * endDate = [startDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
					operatorString = [NSString stringWithFormat:@">=%f and %@<%f", [startDate timeIntervalSince1970], [field sqlField], [endDate timeIntervalSince1970]];
					valueString = @"";
				}
				else
				{
					NSCalendarDate * theDate = [NSCalendarDate dateWithString:[criteria value] calendarFormat:@"%d/%m/%y"];
					valueString = [NSString stringWithFormat:@"%f", [theDate timeIntervalSince1970]];
				}
				break;
				}

			case MA_FieldType_String:
			case MA_FieldType_Integer:
				valueString = [criteria value];
				break;
		}
		
		if (count++ > 0)
			sqlString = [sqlString stringByAppendingString:@" and "];
		sqlString = [sqlString stringByAppendingString:[field sqlField]];
		sqlString = [sqlString stringByAppendingFormat:operatorString, valueString];
	}
	return sqlString;
}

/* arrayOfMessagesNumbers
 * Retrieves a sorted array of NSNumber objects representing the message numbers in the
 * specified folder.
 */
-(NSArray *)arrayOfMessagesNumbers:(int)folderId
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray array];

	if (folder != nil)
	{
		// If we've already cached the messages for this folder then get the message
		// numbers from the cache rather than hit the database.
		if ([folder messageCount] >= 0)
		{
			NSEnumerator * enumerator = [[folder messages] objectEnumerator];
			VMessage * message;

			while ((message = [enumerator nextObject]) != nil)
			{
				[newArray addObject:[NSNumber numberWithInt:[message messageId]]];
			}
		}
		else
		{
			SQLResult * results;

			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			results = [sqlDatabase performQueryWithFormat:@"select message_id from messages where folder_id=%d", folderId];
			if (results && [results rowCount])
			{
				NSEnumerator * enumerator = [results rowEnumerator];
				SQLRow * row;

				while ((row = [enumerator nextObject]) != nil)
				{
					int messageId = [[row stringForColumn:@"message_id"] intValue];
					[newArray addObject:[NSNumber numberWithInt:messageId]];
				}
			}
			// static analyser complains
			//  [results release];
		}
	}
	return [newArray sortedArrayUsingSelector:@selector(compare:)];
}

-(NSString *)convertFromISO:(NSString *)messageText
{// this method is only used to display the message title.  Should it be call convertToISO
	NSString *mactext;
	NSData * chardata = [[NSData alloc] initWithBytes:[messageText
													   cStringUsingEncoding:NSWindowsCP1252StringEncoding]
											   length:[messageText length]];
// this uses ISOLatin1, replacement uses CP1252, which makes this method rather pointless
//	mactext = [[NSString alloc] initWithData: chardata encoding: NSISOLatin1StringEncoding];
	mactext = [[NSString alloc] initWithData: chardata encoding: NSWindowsCP1252StringEncoding];

	[chardata release];
	
	return mactext;
}

/* arrayOfMessages
 * Retrieves an array containing all messages (except for text) for the
 * current folder. This info is always cached.
 */
-(NSArray *)arrayOfMessages:(int)folderId filterString:(NSString *)filterString withoutIgnored:(BOOL)withoutIgnored sorted:(BOOL *)sorted
{
	Folder * folder = [self folderFromID:folderId];
	NSMutableArray * newArray = [NSMutableArray array];
	int unread_count = 0;
	int priority_unread_count = 0;
	*sorted = YES;

	if (folder != nil)
	{
		SQLResult * results;
		NSString * filterClause = @"";

		[folder clearMessages];
		
		if ([filterString isNotEqualTo:@""])
			filterClause = [NSString stringWithFormat:@" and text like '%%%@%%'", filterString];

		if (withoutIgnored)
			filterClause = [filterClause stringByAppendingString:@" and ignored_flag=0"];
		
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		if (!IsSearchFolder(folder))
			results = [sqlDatabase performQueryWithFormat:@"select * from messages where folder_id=%d%@", folderId, filterClause];
		else
		{
			[self initSearchFoldersArray];
			VCriteriaTree * searchString = [searchFoldersArray objectForKey:[NSNumber numberWithInt:folderId]];
			results = [sqlDatabase performQueryWithFormat:@"select * from messages where %@%@", [self criteriaToSQL:searchString], filterClause];
		}

		if (results && [results rowCount])
		{
			NSEnumerator * enumerator = [results rowEnumerator];
			int lastMessageId = -1;
			SQLRow * row;

			while ((row = [enumerator nextObject]) != nil)
			{
				int messageId = [[row stringForColumn:@"message_id"] intValue];
				int commentId = [[row stringForColumn:@"comment_id"] intValue];
				int messageFolderId = [[row stringForColumn:@"folder_id"] intValue];
				NSString * messageTitle = [row stringForColumn:@"title"];
				NSString * messageSender = [row stringForColumn:@"sender"];
				BOOL read_flag = [[row stringForColumn:@"read_flag"] intValue];
				BOOL marked_flag = [[row stringForColumn:@"marked_flag"] intValue];
				BOOL priority_flag = [[row stringForColumn:@"priority_flag"] intValue];
				BOOL ignored_flag = [[row stringForColumn:@"ignored_flag"] intValue];
				NSString * guid = [row stringForColumn:@"rss_guid"];
				NSDate * messageDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"date"] doubleValue]];

				// Flag whether the numbers were retrieved out of order. This can necessiate an
				// extra sort.
				if (messageId < lastMessageId)
					*sorted = NO;
				
				// Keep our own track of unread messages
				if (!read_flag)
				{
					if (priority_flag)
						++priority_unread_count;
					++unread_count;
				}
				
				messageTitle = [self convertFromISO: messageTitle];
				
				VMessage * message = [[VMessage alloc] initWithInfo:messageId];
				[message setComment:commentId];
				[message setTitle:messageTitle];
				[message setSender:messageSender];
				[message setDateFromDate:messageDate];
				[message setGuid:guid];
				[message markRead:read_flag];
				[message markFlagged:marked_flag];
				[message markPriority:priority_flag];
				[message markIgnored:ignored_flag];
				[message setFolderId:messageFolderId];
				[newArray addObject:message];
				[folder addMessage:message];
				[message release];

				lastMessageId = messageId;
			}

			// This is a good time to do a quick check to ensure that our
			// own count of unread is in sync with the folders count and fix
			// them if not.
			if ([filterString isEqualTo:@""])
			{
				if (unread_count != [folder unreadCount])
				{
					NSLog(@"Fixing unread count for %@ (%d on folder versus %d in messages) for folder_id %d, parent %d", 
						  [folder name], [folder unreadCount], unread_count, [folder itemId], [folder parentId]);
					[self setFolderUnreadCount:folder adjustment:(unread_count - [folder unreadCount])];
					[self flushFolder:folderId];
				}
				if (priority_unread_count != [folder priorityUnreadCount])
				{
					NSLog(@"Fixing priority unread count for %@ (%d on folder versus %d in messages) for folder_id %d, parent %d", 
						  [folder name], [folder priorityUnreadCount], priority_unread_count, [folder itemId], [folder parentId]);
					countOfPriorityUnread += priority_unread_count - [folder priorityUnreadCount];
					[folder setPriorityUnreadCount:priority_unread_count];
					[self flushFolder:folderId];
				}
			}
		}

		// Deallocate
		// static analyser complains 
		// [results release];
	}
	return newArray;
}

/* wrappedMarkFolderRead
 * Mark all messages in the folder and sub-folders read. This should be called
 * within a transaction since it is SQL intensive.
 */
-(void)wrappedMarkFolderRead:(int)folderId
{
	NSArray * arrayOfChildFolders = [self arrayOfFolders:folderId];
	NSEnumerator * enumerator = [arrayOfChildFolders objectEnumerator];
	Folder * folder;
	
	// Recurse and mark child folders read too
	while ((folder = [enumerator nextObject]) != nil)
		[self wrappedMarkFolderRead:[folder itemId]];

	folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Verify we're on the right thread
		[self verifyThreadSafety];
		
		SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=1 where folder_id=%d", folderId];
		if (results)
		{
			int count = [folder unreadCount];
			if ([folder messageCount] > 0)
			{
				NSArray * messages = [folder messages];
				NSEnumerator * enumerator = [messages objectEnumerator];
				VMessage * message;
				
				while ((message = [enumerator nextObject]) != nil)
					[message markRead:YES];
			}
			[self setFolderUnreadCount:folder adjustment:-count];
			countOfPriorityUnread -= [folder priorityUnreadCount];
			[folder setPriorityUnreadCount:0];
			[self flushFolder:folderId];
		}
		// static analyser complains
		// [results release];
	}
}

/* markFolderRead
 * Mark all messages in the specified folder read
 */
-(void)markFolderRead:(int)folderId
{
	[self beginTransaction];
	[self wrappedMarkFolderRead:folderId];
	[self commitTransaction];
}

/* markFolderLocked
 * Mark the specified folder locked.
 */
-(void)markFolderLocked:(int)folderId isLocked:(BOOL)isLocked
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		if (isLocked)
			[folder setPermissions:[folder permissions] | MA_LockedFolder];
		else
			[folder setPermissions:[folder permissions] & ~MA_LockedFolder];
		[self executeSQLWithFormat:@"update folders set permissions=%d where folder_id=%d", [folder permissions], folderId];
	}
}

/* markMessageRead
 * Marks a message as read or unread.
 */
-(void)markMessageRead:(int)folderId messageId:(int)messageId isRead:(BOOL)isRead
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];

		VMessage * message = [folder messageFromID:messageId];
		if (message != nil && isRead != [message isRead])
		{
			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			// Mark an individual message read
			SQLResult * results = [sqlDatabase performQueryWithFormat:@"update messages set read_flag=%d where folder_id=%d and message_id=%d", isRead, folderId, messageId];
			if (results)
			{
				int adjustment = (isRead ? -1 : 1);

				[message markRead:isRead];
				[self setFolderUnreadCount:folder adjustment:adjustment];
				if ([message isPriority])
				{
					[folder setPriorityUnreadCount:[folder priorityUnreadCount] + adjustment];
					countOfPriorityUnread += adjustment;
				}
			}
			// static analyser complains
			// [results release];
		}
	}
}

/* setFolderUnreadCount
 */
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(int)adjustment
{
	int unreadCount = [folder unreadCount];
	[folder setUnreadCount:unreadCount + adjustment];
	
	// Update childUnreadCount for our parent. Since we're just working
	// on one message, we do this the faster way.
	while ([folder parentId] != -1)
	{
		folder = [self folderFromID:[folder parentId]];
		[folder setChildUnreadCount:[folder childUnreadCount] + adjustment];
	}
}

/* markMessageFlagged
 * Marks a message as flagged or unflagged.
 */
-(void)markMessageFlagged:(int)folderId messageId:(int)messageId isFlagged:(BOOL)isFlagged
{
	[self verifyThreadSafety];
	[self executeSQLWithFormat:@"update messages set marked_flag=%d where folder_id=%d and message_id=%d", isFlagged, folderId, messageId];
}

/* markMessageIgnored
 * Marks a message as ignored or not ignored.
 */
-(void)markMessageIgnored:(int)folderId messageId:(int)messageId isIgnored:(BOOL)isIgnored
{
	[self verifyThreadSafety];
	[self executeSQLWithFormat:@"update messages set ignored_flag=%d where folder_id=%d and message_id=%d", isIgnored, folderId, messageId];
}

/* markMessagePriority
 * Marks a message as priority or normal. If the message is unread then we adjust the folder
 * priority unread count up or down as appropriate.
 */
-(void)markMessagePriority:(int)folderId messageId:(int)messageId isPriority:(BOOL)isPriority
{
	Folder * folder = [self folderFromID:folderId];
	if (folder != nil)
	{
		// Prime the message cache
		[self initMessageArray:folder];
		
		VMessage * message = [folder messageFromID:messageId];
		if (message != nil && isPriority != [message isPriority])
		{
			int adjustment = (isPriority ? 1 : -1);

			// Verify we're on the right thread
			[self verifyThreadSafety];
			
			[self executeSQLWithFormat:@"update messages set priority_flag=%d where folder_id=%d and message_id=%d", isPriority, folderId, messageId];
			if (![message isRead])
			{
				[folder setPriorityUnreadCount:[folder priorityUnreadCount] + adjustment];
				countOfPriorityUnread += adjustment;
			}
		}
	}
}

// Fill a dictionary full of RSS Guids so we can weed out duplicates
-(void)loadRSSGuids:(id)ignored
{
	if (RSSGuids)
		return;
		
	RSSGuids = [[NSMutableDictionary alloc] init];

	SQLResult *results;
	
	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	results = [sqlDatabase performQueryWithFormat:@"select title, rss_guid from messages where rss_guid not null and rss_guid <> ''"];
	if (results && [results rowCount] > 0)
	{
		NSEnumerator * enumerator = [results rowEnumerator];
		SQLRow * row;

		while ((row = [enumerator nextObject]) != nil)
		{
			NSString * title = [row stringForColumn:@"title"];
			NSString * guid = [row stringForColumn:@"rss_guid"];
			[RSSGuids setObject: title forKey:guid];
		}
	}
	// static analyser complains
	// [results release];
}

/* messageText
 * Retrieve the text of the specified message.
 */
-(NSString *)messageText:(int)folderId messageId:(int)messageId
{
	SQLResult * results;
	NSString * text;

	// Verify we're on the right thread
	[self verifyThreadSafety];
	
	results = [sqlDatabase performQueryWithFormat:@"select text from messages where folder_id=%d and message_id=%d", folderId, messageId];
	if (results && [results rowCount] > 0)
	{
		int lastRow = [results rowCount] - 1;
		text = [[results rowAtIndex:lastRow] stringForColumn:@"text"];
	}
	else
		text = @"** Cannot retrieve text for message **";
	// static analsyer complains
	// [results release];
	return text;
}

-(NSMutableDictionary *)getRSSGuids
{
	return RSSGuids;
}

/* Remove everything from the forums and categories tables
 * ready for a new conference list download.
 */
-(void)cleanBrowserTables
{
	NSLog(@"Start cleaning browswer tables");
	[self executeSQL:@"delete from forums"];
	[self executeSQL:@"delete from categories"];
	NSLog(@"End cleaning browser tables");
}


/* close
 * Close the database.
 */
-(void)close
{
	[foldersArray release];
	[searchFoldersArray release];
	[forumArray release];
	[categoryArray release];
	[rssFeedArray release];
	[personArray release];
	[sqlDatabase close];
	initializedFoldersArray = NO;
	initializedSearchFoldersArray = NO;
	initializedForumArray = NO;
	sqlDatabase = nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	if (sqlDatabase)
		[self close];
	[sqlDatabase release];
	[fieldsOrdered release];
	[fieldsByTitle release];
	[fieldsByName release];
	[iconArray release];
	[RSSGuids release];
	[super dealloc];
}
@end
