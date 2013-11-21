//
//  Message.h
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

extern NSString * MA_Column_MessageId;
extern NSString * MA_Column_MessageTitle;
extern NSString * MA_Column_MessageFrom;
extern NSString * MA_Column_MessageDate;
extern NSString * MA_Column_MessageComment;
extern NSString * MA_Column_MessageUnread;
extern NSString * MA_Column_MessageFlagged;
extern NSString * MA_Column_MessageText;
extern NSString * MA_Column_MessageFolderId;
extern NSString * MA_Column_MessagePriority;
extern NSString * MA_Column_MessageIgnored;
extern NSString * MA_Column_MessageGuid;

// Custom values for message IDs
#define MA_MsgID_New			-1
#define MA_MsgID_RSSNew			-2

#define MA_ID_MessageId			400
#define MA_ID_MessageTitle		401
#define MA_ID_MessageFrom		402
#define MA_ID_MessageDate		403
#define MA_ID_MessageComment	404
#define MA_ID_MessageUnread		405
#define MA_ID_MessageFlagged	406
#define MA_ID_MessageText       407
#define MA_ID_MessageFolderId   408
#define MA_ID_MessagePriority   409
#define MA_ID_MessageIgnored    410
#define MA_ID_MessageGuid		411

@interface VMessage : NSObject {
	NSMutableDictionary * messageData;
	NSInteger level;
	VMessage * lastChildMessage;
	BOOL readFlag;
	BOOL markedFlag;
	BOOL priorityFlag;
	BOOL ignoredFlag;
}
-(id)initWithInfo:(NSInteger)messageId;
-(NSInteger)messageId;
-(NSString *)sender;
-(NSString *)text;
-(NSString *)title;
-(NSDate *)date;
-(NSString *)guid;
-(NSInteger)folderId;
-(NSInteger)comment;
-(NSInteger)level;
-(BOOL)isRead;
-(BOOL)isFlagged;
-(BOOL)isPriority;
-(BOOL)isIgnored;
-(VMessage *)lastChildMessage;
-(void)setNumber:(NSInteger)newMessageId;
-(void)setComment:(NSInteger)newMessageComment;
-(void)setTitle:(NSString *)newMessageTitle;
-(void)setSender:(NSString *)newSender;
-(void)setLevel:(NSInteger)n;
-(void)setFolderId:(NSInteger)newFolderId;
-(void)setLastChildMessage:(VMessage *)message;
-(void)setDateFromDate:(NSDate *)newMessageDate;
-(void)setGuid:(NSString *)setGuid;
-(void)setText:(NSString *)newText;
-(void)markRead:(BOOL)flag;
-(void)markFlagged:(BOOL)flag;
-(void)markPriority:(BOOL)flag;
-(void)markIgnored:(BOOL)flag;
-(NSDictionary *)messageData;
@end
