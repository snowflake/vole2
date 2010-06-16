//
//  Socket.h
//  Vienna
//
//  Created by Steve on Sun Feb 29 2004.
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
#import "Logfile.h"

@interface Socket : NSObject {
	NSString * address;
	char pushedChar;
	int timeout;
	int port;
	int fd;
	Logfile *logFile;
}

-(id)initWithAddress:(NSString *)theAddress port:(int)thePort;
-(NSString *)address;
-(int)port;
-(int)getFd;
-(BOOL)isConnected;
-(BOOL)connect;
-(char)peekChar;
-(void)setNonBlocking:(BOOL)yesno;
-(int)setTimeout:(int)newTimeout;
-(BOOL)sendLine:(NSString *)stringToSend;
-(BOOL)sendBytes:(const char *)data length:(int)length;
-(BOOL)sendStringWithFormat:(NSString *)format, ...;
-(BOOL)sendString:(NSString *)stringToSend;
-(char)readChar:(BOOL *)endOfFile;
-(NSString *)readLine:(BOOL *)endOfFile;
-(NSString *)readDataOfLength:(BOOL *)endOfFile length:(int)length;
-(BOOL)readData:(char *)dataBlock length:(int)length;
-(void)unreadChar:(char)ch;
-(void)setLogFile:(NSString *)name versions:(int)versions;
-(void)close;

@end
