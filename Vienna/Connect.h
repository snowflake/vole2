//
//  Connect.h
//  Vienna
//
//  Created by Steve on Thu Mar 04 2004.
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
#import "Database.h"
#import "Socket.h"
#import "Credentials.h"

// Service flags (must be a bitmask)
#define MA_Service_CIX		1
#define MA_Service_RSS		2

// Error conditions
enum {
	MA_Connect_Success = 0,
	MA_Connect_BadUsername,
	MA_Connect_BadPassword,
	MA_Connect_AlreadyConnected,
	MA_Connect_ServiceUnavailable,
	MA_Connect_Aborted
};

// Connection Modes.
enum {
	MA_ConnectMode_Both = 0,
	MA_ConnectMode_Cix,
	MA_ConnectMode_RSS
};

@interface Connect : NSObject {
	Credentials * credentials;
	BOOL isCIXThreadRunning;
	BOOL isRSSThreadRunning;
	BOOL cixAbortFlag;
	BOOL rssAbortFlag;
	BOOL shuttingDown;
	id delegate;
	BOOL isPushedLine;
	NSString * pushedLine;
	Socket * socket;
	Database * db;
	int lastTopicId;
	BOOL online;
	int taskRunningCount;
	BOOL usingSSH;
	int connectMode;
	unsigned int messagesCollected;
	NSMutableArray * messagesToPost;
	NSArray * rssArray;
	NSMutableArray * tasksArray;
	NSConditionLock * condLock;
}

// General functions
-(id)initWithCredentials:(Credentials *)theCredentials;
-(NSString *)username;
-(NSString *)password;
-(void)disconnectFromService;
-(NSString *)serviceString;
-(void)abortConnect;
-(void)setOnline:(BOOL)theOnline;
-(void)processOfflineTasks;
-(void)processSingleTask:(VTask *)task;
-(BOOL)isProcessing;
-(unsigned int)messagesCollected;
-(int)connectToService;
-(void)setDelegate:(id)newDelegate;
-(void)setDatabase:(Database *)database;
-(void)connectThread:(NSObject *)object;
-(void)markMessagePosted:(VMessage *)message;
-(void)updateLastFolder:(NSNumber *)number;
-(void)stopCIXConnectThread;
-(void)setMode:(int)newMode;

// Delegate interfaces
-(void)sendActivityStringToDelegate:(NSString *)string;
-(void)sendStatusToDelegate:(NSString *)statusString;
-(void)sendStartConnectToDelegate;
-(void)sendEndConnectToDelegate:(int)result;
@end
