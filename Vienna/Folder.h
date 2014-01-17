//
//  Folder.h
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

#import <Foundation/Foundation.h>
#import "Vole.h"
#import "VMessage.h"

@interface Folder : NSObject {
	NSString * name;
	NSString * description;
	NSString * link;
	NSInteger itemId;
	NSInteger parentId;
	NSInteger unreadCount;
	NSInteger permissions;
	NSInteger childUnreadCount;
	NSInteger priorityUnreadCount;
	BOOL hasDescription;
	BOOL isMessages;
	BOOL isUnreadCountChanged;
	NSMutableDictionary * messages;
}
-(id)initWithId:(NSInteger)itemId parentId:(NSInteger)parentId name:(NSString *)name permissions:(NSInteger)permissions;
-(NSString *)name;
-(NSString *)description;
-(NSString *)link;
-(NSInteger)parentId;
-(NSInteger)itemId;
-(NSInteger)messageCount;
-(NSInteger)unreadCount;
-(NSInteger)permissions;
-(NSInteger)priorityUnreadCount;
-(NSInteger)childUnreadCount;
-(void)clearMessages;
-(BOOL)isUnreadCountChanged;
-(BOOL)hasDescription;
-(void)resetUnreadCountChanged;
-(void)setName:(NSString *)name;
-(void)setUnreadCount:(NSInteger)count;
-(void)setPermissions:(NSInteger)permissions;
-(void)setPriorityUnreadCount:(NSInteger)count;
-(void)setChildUnreadCount:(NSInteger)count;
-(void)setDescription:(NSString *)newDescription;
-(void)setLink:(NSString *)newLink;
-(NSArray *)messages;
-(VMessage *)messageFromID:(NSInteger)messageId;
-(void)addMessage:(VMessage *)newMessage;
-(void)deleteMessage:(NSInteger)messageId;
-(void)markFolderEmpty;
-(NSComparisonResult)folderCompare:(Folder *)otherObject;
-(NSComparisonResult)topLevelFolderCompare:(Folder *)otherObject;
@end
