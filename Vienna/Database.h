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
#import "Vole.h"

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
	NSInteger databaseVersion;
	NSInteger countOfPriorityUnread;
	NSInteger cachedRSSNodeID;
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
-(NSInteger)databaseVersion;
-(void)beginTransaction;
-(void)commitTransaction;
-(void)compactDatabase;
-(BOOL)readOnly;
-(void)close;

// Fields functions
-(void)addField:(NSString *)name title:(NSString *)title type:(NSInteger)type tag:(NSInteger)tag sqlField:(NSString *)sqlField visible:(BOOL)visible width:(NSInteger)width;
-(NSArray *)arrayOfFields;
-(VField *)fieldByIdentifier:(NSString *)identifier;
-(VField *)fieldByTitle:(NSString *)title;

// Folder functions
-(void)initFolderArray;
-(NSArray *)arrayOfFolders:(NSInteger)parentID;
-(Folder *)folderFromID:(NSInteger)wantedId;
-(Folder *)folderFromIDAndName:(NSInteger)wantedParentId name:(NSString *)wantedName;
-(NSInteger)addFolder:(NSInteger)conferenceId folderName:(NSString *)name permissions:(NSInteger)permissions mustBeUnique:(BOOL)mustBeUnique;
-(NSInteger)addFolderByPath:(NSInteger)parentId path:(NSString *)path;
-(BOOL)deleteFolder:(NSInteger)folderId;
-(BOOL)setFolderName:(NSInteger)folderId newName:(NSString *)newName;
-(BOOL)setFolderDescription:(NSInteger)folderId newDescription:(NSString *)newDescription;
-(BOOL)setFolderLink:(NSInteger)folderId newLink:(NSString *)newLink;
-(void)flushFolder:(NSInteger)folderId;
-(void)releaseMessages:(NSInteger)folderId;
-(void)markFolderRead:(NSInteger)folderId;
-(void)markFolderLocked:(NSInteger)folderId isLocked:(BOOL)isLocked;
-(void)setFolderUnreadCount:(Folder *)folder adjustment:(NSInteger)adjustment;
-(NSInteger)countOfPriorityUnread;
-(NSString *)folderPathName:(NSInteger)folderId;
-(NSInteger)conferenceNodeID;
-(NSInteger)rssNodeID;
-(NSImage *)imageForFolder:(Folder *)folder;

// RSS feed functions
-(NSArray *)arrayOfRSSFolders;
-(RSSFolder *)rssFolderFromId:(NSInteger)folderId;
-(RSSFolder *)rssFolderFromURL:(NSString *)url;
-(NSInteger)addRSSFolder:(NSString *)feedName subscriptionURL:(NSString *)url;
-(BOOL)setRSSFolderFeed:(NSInteger)folderId subscriptionURL:(NSString *)url;
-(void)setRSSFeedLastUpdate:(NSInteger)folderId lastUpdate:(NSDate *)lastUpdate;

// Forum functions
-(NSInteger)addForum:(Forum *)newForum;
-(NSInteger)addCategory:(Category *)newCategory;
-(NSArray *)arrayOfForums:(NSInteger)status inCategory:(NSInteger)categoryId;
-(NSArray *)arrayOfCategories:(NSInteger)parentId;
-(Category *)findCategory:(NSInteger)parentId name:(NSString *)name;
-(void)cleanBrowserTables;

// Search Folder functions
-(void)initSearchFoldersArray;
-(BOOL)createSearchFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree;
-(BOOL)updateSearchFolder:(NSInteger)folderId withFolder:(NSString *)folderName withQuery:(VCriteriaTree *)criteriaTree;
-(VCriteriaTree *)searchStringForSearchFolder:(NSInteger)folderId;
-(NSString *)criteriaToSQL:(VCriteriaTree *)criteriaTree;

// Tasks functions
-(void)initTasksArray;
-(NSArray *)arrayOfTasks:(BOOL)onlyReadyTasks;
-(VTask *)addTask:(NSInteger)action_code actionData:(NSString *)actionData folderName:(NSString *)folderName orderCode:(NSInteger)orderCode;
-(VTask *)addTask:(VTask *)task;
-(void)deleteTask:(VTask *)task;
-(VTask *)findTask:(NSInteger)wantedActionCode wantedActionData:(NSString *)wantedActionData;
-(void)setTaskCompleted:(VTask *)task;
-(void)setTaskWaiting:(VTask *)task;
-(void)setTaskRunning:(VTask *)task;
-(void)updateTask:(VTask *)task;
-(void)clearTasks:(NSInteger)tasksFlag;

// Person data functions
-(VPerson *)retrievePerson:(NSString *)name;
-(void)updatePerson:(NSString *)name data:(NSString *)data;

// Message functions
-(BOOL)initMessageArray:(Folder *)folder;
-(NSInteger)addMessage:(NSInteger)folderID message:(VMessage *)message wasNew:(BOOL *)wasNew;
-(NSInteger)addMessageToFolder:(NSInteger)folderId path:(NSString *)path message:(VMessage *)message raw:(BOOL)raw wasNew:(BOOL *)wasNew;
-(BOOL)deleteMessage:(NSInteger)folderId messageNumber:(NSInteger)messageNumber;
-(NSArray *)arrayOfMessages:(NSInteger)folderId filterString:(NSString *)filterString withoutIgnored:(BOOL)withoutIgnored sorted:(BOOL *)sorted;
-(NSArray *)arrayOfChildMessages:(NSInteger)folderId messageId:(NSInteger)messageId;
-(NSArray *)arrayOfMessagesNumbers:(NSInteger)folderId;
-(void)buildArrayOfChildMessages:(NSMutableArray *)newArray folder:(Folder *)folder messageId:(NSInteger)messageId searchIndex:(NSUInteger)searchIndex;
-(NSString *)messageText:(NSInteger)folderId messageId:(NSInteger)messageId;
-(void)markMessageRead:(NSInteger)folderId messageId:(NSInteger)messageId isRead:(BOOL)isRead;
-(void)markMessageFlagged:(NSInteger)folderId messageId:(NSInteger)messageId isFlagged:(BOOL)isFlagged;
-(void)markMessagePriority:(NSInteger)folderId messageId:(NSInteger)messageId isPriority:(BOOL)isPriority;
-(void)markMessageIgnored:(NSInteger)folderId messageId:(NSInteger)messageId isIgnored:(BOOL)isIgnored;
-(NSArray *)findMessages:(NSDictionary *)criteriaDictionary;
-(void)loadRSSGuids:(id)ignored;
-(NSMutableDictionary *)getRSSGuids;


// Spotlight metatdata functions
-(void)removeSpotlightMetadata:(NSInteger)messageId folder:(NSInteger)folderId;
-(void)addSpotlightMetadata:(NSInteger)messageId folder:(NSInteger)folderId sender:(NSString *)senderName date:(NSDate *)date text:(NSString *)text;
-(NSString *)createSpotlightFolder:(NSInteger)folderId message:(NSInteger)messageId;

@end
