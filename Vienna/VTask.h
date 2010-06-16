//
//  VTask.h
//  Vienna
//
//  Created by Steve on Sun Apr 04 2004.
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

// Tasks codes
// Note: MA_TaskCode_NoTask is a sentinel.
//
#define MA_TaskCode_NoTask			0
#define MA_TaskCode_ReadMessages	1
#define MA_TaskCode_PostMessages	2
#define MA_TaskCode_ResignFolder	3
#define MA_TaskCode_JoinFolder		4
#define MA_TaskCode_FileMessages	5
#define MA_TaskCode_WithdrawMessage 6
#define MA_TaskCode_ConfList        7
#define MA_TaskCode_SkipBack		8
#define MA_TaskCode_GetResume		9
#define MA_TaskCode_PutResume		10
#define MA_TaskCode_GetRSS			11
#define MA_TaskCode_ModAddPart		12
#define MA_TaskCode_ModRemPart		13
#define MA_TaskCode_ModNewConf		14
#define MA_TaskCode_ModRdOnly		15
#define MA_TaskCode_ModAddTopic		16
#define MA_TaskCode_ModComod		17
#define MA_TaskCode_ModExmod		18
#define MA_TaskCode_FileDownload	19
#define MA_TaskCode_FileUpload		20
#define MA_TaskCode_SetCIXBack		21

// Result codes
//
#define MA_TaskResult_Succeeded		1
#define MA_TaskResult_Waiting		2
#define MA_TaskResult_Failed		3
#define MA_TaskResult_Running		4

// Order codes
// Codes with lower values get run earlier than those ones with higher values.
// Note:
//  Post messages before resigning a folder so we can post and then resign in the same connect.
//  Need to join a folder before we can do anything involving that folder (posting, filing or withdrawing messages)
//  Leave the heavy duty actions (e.g. reading the conference list) until last so the user can read new messages while this is going on.
//  I've added Moderator functions right at the top so we can create & post a message to that conf in the same blink. 

#define MA_OrderCode_SetCIXBack			50
#define MA_OrderCode_Mod				80
#define MA_OrderCode_JoinFolder			90
#define MA_OrderCode_PostMessages		100
#define MA_OrderCode_FileMessages		220
#define MA_OrderCode_WithdrawMessage	230
#define MA_OrderCode_SkipBack			235
#define MA_OrderCode_ResignFolder		240
#define MA_OrderCode_ReadMessages		600
#define MA_OrderCode_FileUpload			650
#define MA_OrderCode_FileDownload		650
#define MA_OrderCode_ConfList			700
#define MA_OrderCode_PutResume			750
#define MA_OrderCode_GetResume			755
#define MA_OrderCode_GetRSS				800

@interface VTask : NSObject {
	int taskId;
	int orderCode;
	int actionCode;
	int resultCode;
	NSString * actionData;
	NSString * folderName;
	NSString * resultString;
	NSDate * lastRunDate;
	NSDate * earliestRunDate;
}

// Public accessor functions
-(int)taskId;
-(int)orderCode;
-(int)actionCode;
-(NSString *)actionData;
-(NSString *)folderName;
-(int)resultCode;
-(NSString *)resultString;
-(NSDate *)lastRunDate;
-(NSDate *)earliestRunDate;

-(void)setTaskId:(int)newTaskId;
-(void)setOrderCode:(int)orderCode;
-(void)setActionCode:(int)newActionCode;
-(void)setActionData:(NSString *)newActionData;
-(void)setFolderName:(NSString *)newFolderName;
-(void)setResultCode:(int)newResultCode;
-(void)setResultString:(NSString *)newResultString;
-(void)setResultStringWithFormat:(NSString *)newResultString, ...;
-(void)setLastRunDate:(NSDate *)newLastRunDate;
-(void)setEarliestRunDate:(NSDate *)newEarliestRunDate;

// Other functions
-(BOOL)compareForUniqueness:(VTask *)task;
-(NSComparisonResult)taskCompare:(VTask *)otherObject;
@end
