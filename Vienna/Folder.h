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
	int itemId;
	int parentId;
	int unreadCount;
	int permissions;
	int childUnreadCount;
	int priorityUnreadCount;
	BOOL hasDescription;
	BOOL isMessages;
	BOOL isUnreadCountChanged;
	NSMutableDictionary * messages;
}
-(id)initWithId:(int)itemId parentId:(int)parentId name:(NSString *)name permissions:(int)permissions;
-(NSString *)name;
-(NSString *)description;
-(NSString *)link;
-(int)parentId;
-(int)itemId;
-(int)messageCount;
-(int)unreadCount;
-(int)permissions;
-(int)priorityUnreadCount;
-(int)childUnreadCount;
-(void)clearMessages;
-(BOOL)isUnreadCountChanged;
-(BOOL)hasDescription;
-(void)resetUnreadCountChanged;
-(void)setName:(NSString *)name;
-(void)setUnreadCount:(int)count;
-(void)setPermissions:(int)permissions;
-(void)setPriorityUnreadCount:(int)count;
-(void)setChildUnreadCount:(int)count;
-(void)setDescription:(NSString *)newDescription;
-(void)setLink:(NSString *)newLink;
-(NSArray *)messages;
-(VMessage *)messageFromID:(int)messageId;
-(void)addMessage:(VMessage *)newMessage;
-(void)deleteMessage:(int)messageId;
-(void)markFolderEmpty;
-(NSComparisonResult)folderCompare:(Folder *)otherObject;
-(NSComparisonResult)topLevelFolderCompare:(Folder *)otherObject;
@end
