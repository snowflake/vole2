//
//  BufferedFile.h
//  Vienna
//
//  Created by Steve on Wed Feb 04 2004.
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

@interface BufferedFile : NSObject {
	NSFileHandle * fileHandle;
	NSData * buffer;
	NSInteger bytesInBuffer;
	NSInteger bufferIndex;
	char pushedChar;
	NSInteger readSoFar;
	NSInteger fileSize;
}

-(id)initWithPath:(NSString *)filePath;
-(id)initWithFileHandle:(NSFileHandle *)h;
-(NSInteger)readSoFar;
-(NSInteger)fileSize;
-(NSString *)readLine:(BOOL *)endOfFile;
-(NSString *)readTextOfSize:(NSInteger)textSize;
-(char)readChar;
-(char)readUnixChar:(NSInteger *)charSizePtr;
-(void)unreadChar:(char)ch;
-(void)close;
@end
