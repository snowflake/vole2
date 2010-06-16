//
//  Database.h
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

#import <Foundation/Foundation.h>
#import "SQLDatabase.h"
#import "Folder.h"
#import "Forum.h"
#import "Category.h"
#import "TreeNode.h"
#import "VField.h"
#import "VTask.h"
#import "VCriteria.h"
#import "VPerson.h"
#import "RSSFolder.h"

@interface Database : NSObject {
	SQLDatabase * sqlDatabase;
	BOOL initializedFoldersArray;
	BOOL initializedSearchFoldersArray;
	BOOL initializedTasksArray;
	BOOL initializedForumArray;
	BOOL initializedPersonArray;
	BOOL initializedRSSArray;
	BOOL readOnly;
	int databaseVersion;
	int countOfPriorityUnread;
	int cachedRSSNodeID;
	NSThread * mainThread;
	BOOL inTransaction;
	NSString * username;
	NSMutableArray * fieldsOrdered;
	NSMutableDictionary * fieldsByName;
	NSMutableDictionary * fieldsByTitle;
	NSMutableDictionary * foldersArray;
	NSMutableDictionary * searchFoldersArray;
	NSMutableDictionary * forumArray;
	NSMutableDictionary * categoryArray;
	NSMutableDictionary * personArray;
	NSMutableDictionary * rssFeedArray;
	NSMutableArray * tasksArray;
	NSMutableDictionary * RSSGuids;
	NSArray * iconArray;
}

// General database functions
-(BOOL)initDatabase:(NSString *)databaseFileName;
-(void)syncLastUpdate;
-(void)setUsername:(NSString *)newUsername;
-(int)databaseVersion;
-(void)beginTransaction;
-(void)commitTransaction;
-(void)compactDatabase;
-(BOOL)readOnly;
-(void)close;

// Fields functions
-(void)addField:(NSString *)name title:(NSString *)title type:(int)type tag:(int)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(int)width;
-(NSArray *)arrayOfFields;
-(VField *)fieldByIdentifier:(NSString *)identifier;
-(VField *)fieldByTitle:(NSString *)title;

// Folder functions
-(void)initFolderArray;
-(NSArray *)arrayOfFolders:(int)parentID;
-(Folder *)folderFromID:(int)wantedId;
-(Folder *)folderFromIDAndName:(int)wantedParentId name:(NSString *)wantedName;
-(int)addFolder:(int)conferenceId folderName:(NSString *)name permissions:(int)permissions mustBeUnique:(BOOL)mustBeUnique;
-(int)addFolderByPath:(int)parentId path:(NSString *)path;
-(BOOL)deleteFolder:(int)folderId;
-(BOOL)setFolderName:(int)folderId newName:(NSString *)newName;
-(BOOL)setFolderDescription:(int)folderId newDescription:(NSString *)newDescription;
-(BOOL)setFolderLink:(int)folderId newLink:(NSString *)newLink;
-(void)flushFolder:(int)folderId;
-(void)releaseMessages:(int)folderId;
-(void)markFolderRead:(int)folderId;
-(void)markFolderLocked:(int)folderId isLocked:(BOOL)isLocked;
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(int)adjustment;
-(int)countOfPriorityUnread;
-(NSString *)folderPathName:(int)folderId;
-(int)conferenceNodeID;
-(int)rssNodeID;
-(NSImage *)imageForFolder:(Folder *)folder;

// RSS feed functions
-(NSArray *)arrayOfRSSFolders;
-(RSSFolder *)rssFolderFromId:(int)folderId;
-(RSSFolder *)rssFolderFromURL:(NSString *)url;
-(int)addRSSFolder:(NSString *)feedName subscriptionURL:(NSString *)url;
-(BOOL)setRSSFolderFeed:(int)folderId subscriptionURL:(NSString *)url;
-(void)setRSSFeedLastUpdate:(int)folderId lastUpdate:(NSDate *)lastUpdate;

// Forum functions
-(int)addForum:(Forum *)newForum;
-(int)addCategory:(Category *)newCategory;
-(NSArray *)arrayOfForums:(int)status inCategory:(int)categoryId;
-(NSArray *)arrayOfCategories:(int)parentId;
-(Category *)findCategory:(int)parentId name:(NSString *)name;
-(void)cleanBrowserTables;

// Search Folder functions
-(void)initSearchFoldersArray;
-(BOOL)createSearchFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree;
-(BOOL)updateSearchFolder:(int)folderId withFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree;
-(VCriteriaTree *)searchStringForSearchFolder:(int)folderId;
-(NSString *)criteriaToSQL:(VCriteriaTree *)criteriaTree;

// Tasks functions
-(void)initTasksArray;
-(NSArray *)arrayOfTasks:(BOOL)onlyReadyTasks;
-(VTask *)addTask:(int)action_code actionData:(NSString *)actionData folderName:(NSString *)folderName orderCode:(int)orderCode;
-(VTask *)addTask:(VTask *)task;
-(void)deleteTask:(VTask *)task;
-(VTask *)findTask:(int)wantedActionCode wantedActionData:(NSString *)wantedActionData;
-(void)setTaskCompleted:(VTask *)task;
-(void)setTaskWaiting:(VTask *)task;
-(void)setTaskRunning:(VTask *)task;
-(void)updateTask:(VTask *)task;
-(void)clearTasks:(int)tasksFlag;

// Person data functions
-(VPerson *)retrievePerson:(NSString *)name;
-(void)updatePerson:(NSString *)name data:(NSString *)data;

// Message functions
-(BOOL)initMessageArray:(Folder *)folder;
-(int)addMessage:(int)folderID message:(VMessage *)message wasNew:(BOOL *)wasNew;
-(int)addMessageToFolder:(int)folderId path:(NSString *)path message:(VMessage *)message raw:(BOOL)raw wasNew:(BOOL *)wasNew;
-(BOOL)deleteMessage:(int)folderId messageNumber:(int)messageNumber;
-(NSArray *)arrayOfMessages:(int)folderId filterString:(NSString *)filterString withoutIgnored:(BOOL)withoutIgnored sorted:(BOOL *)sorted;
-(NSArray *)arrayOfChildMessages:(int)folderId messageId:(int)messageId;
-(NSArray *)arrayOfMessagesNumbers:(int)folderId;
-(void)buildArrayOfChildMessages:(NSMutableArray *)newArray folder:(Folder *)folder messageId:(int)messageId searchIndex:(unsigned int)searchIndex;
-(NSString *)messageText:(int)folderId messageId:(int)messageId;
-(void)markMessageRead:(int)folderId messageId:(int)messageId isRead:(BOOL)isRead;
-(void)markMessageFlagged:(int)folderId messageId:(int)messageId isFlagged:(BOOL)isFlagged;
-(void)markMessagePriority:(int)folderId messageId:(int)messageId isPriority:(BOOL)isPriority;
-(void)markMessageIgnored:(int)folderId messageId:(int)messageId isIgnored:(BOOL)isIgnored;
-(NSArray *)findMessages:(NSDictionary *)criteriaDictionary;
-(void)loadRSSGuids:(id)ignored;
-(NSMutableDictionary *)getRSSGuids;


// Spotlight metatdata functions
-(void)removeSpotlightMetadata:(int)messageId folder:(int)folderId;
-(void)addSpotlightMetadata:(int)messageId folder:(int)folderId sender:(NSString *)senderName date:(NSDate *)date text:(NSString *)text;
-(NSString *)createSpotlightFolder:(int)folderId message:(int)messageId;

@end
