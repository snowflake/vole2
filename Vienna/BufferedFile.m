//
//  BufferedFile.m
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

#import "BufferedFile.h"
#import "sanitise_string.h"

#define BF_LINE_MAX			128
#define BF_STRING_MAX		256
#define BF_BUFFER_MAX		(16 * 1024)

@implementation BufferedFile

/* initWithData
 * Initalizes the instance with data
 */
-(id)initWithPath:(NSString *)filePath
{
	return [self initWithFileHandle:[NSFileHandle fileHandleForReadingAtPath:filePath]];
}

/* initWithFileHandle
 * The designnated initializer
 */
-(id)initWithFileHandle:(NSFileHandle *)h
{
	if ((self = [super init]) != nil)
	{
		fileHandle = h;
		fileSize = [fileHandle seekToEndOfFile];
		[fileHandle seekToFileOffset:0];
		buffer = nil;
		pushedChar = 0;
		bytesInBuffer = 0;
		bufferIndex = 0;
		readSoFar = 0;
	}
	return self;
}

/* readSoFar
 * Returns the number of bytes read so far.
 */
-(NSInteger)readSoFar
{
	return readSoFar;
}

/* fileSize
 * Returns the size of the entire file
 */
-(NSInteger)fileSize
{
	return fileSize;
}

/* readLine
 * Reads one line from the file and returns an NSString containing
 * the line. If we reach the end of the file, endOfFile is YES.
 * Otherwise it is NO.
 */
-(NSString *)readLine:(BOOL *)endOfFile
{
	NSMutableString * lineString = [NSMutableString stringWithCapacity:BF_STRING_MAX];
	char lineBuffer[BF_LINE_MAX];
	NSInteger count;
	char ch;

	ch = [self readChar];
	count = 0;
	while (ch != 0x0D && ch != 0x0A && ch != 0)
	{
		lineBuffer[count++] = ch;
		if (count == BF_LINE_MAX-1)
		{
			lineBuffer[count] = '\0';
			// Deprecated API here DJE
	//		[lineString appendString:[NSString stringWithCString:lineBuffer]];
			// replacement here
			[lineString appendString:[NSString stringWithCString: sanitise_string(lineBuffer)
														encoding:NSWindowsCP1252StringEncoding] ];
			// XXX The acronyms loader depends on CP1252 encoding !!!
			count = 0;
		}
		ch = [self readChar];
	}

	// Handle all possible line endings
	if (ch == 0x0D)
	{
		if ((ch = [self readChar]) != 0x0A)
			[self unreadChar:ch];
	}
	else if (ch == 0x0A)
	{
		if ((ch = [self readChar]) != 0x0D)
			[self unreadChar:ch];
	}

	if (count)
	{
		lineBuffer[count] = '\0';
		// deprecated API here DJE
	//	[lineString appendString:[NSString stringWithCString:lineBuffer]];
		// replacement here 
		[lineString appendString:[NSString stringWithCString:sanitise_string(lineBuffer) encoding:NSWindowsCP1252StringEncoding]];

	}
	*endOfFile = (ch == 0);
	return lineString;
}

/* readTextOfSize
 * Reads textSize characters from the input.
 */
-(NSString *)readTextOfSize:(NSInteger)textSize
{
	NSMutableString * textString = [NSMutableString stringWithCapacity:textSize];
	char textBuffer[BF_LINE_MAX];
	NSInteger charSize;
	NSInteger count;
	char ch;

	ch = [self readUnixChar:&charSize];
	count = 0;
	while (ch && textSize > 0)
	{
		textBuffer[count++] = ch;
		if (count == BF_LINE_MAX-1)
		{
			textBuffer[count] = '\0';
			// deprecated API here DJE
//			[textString appendString:[NSString stringWithCString:textBuffer]];
			// replacement here
			[textString appendString:[NSString stringWithCString:sanitise_string(textBuffer)
														encoding:NSWindowsCP1252StringEncoding]];

			count = 0;
		}
		textSize -= charSize;
		ch = [self readUnixChar:&charSize];
	}
	if (count)
	{
		textBuffer[count] = '\0';
		// deprecated API here DJE
//		[textString appendString:[NSString stringWithCString:textBuffer]];
		// replacement here
		[textString appendString:[NSString stringWithCString:sanitise_string(textBuffer)
													encoding: NSWindowsCP1252StringEncoding]];

	}
	return textString;
}

/* readUnixChar
 * Reads one character from the buffer. Newlines are converted to \n
 */
-(char)readUnixChar:(NSInteger *)charSizePtr
{
	char ch = [self readChar];
	char charSize = 1;

	if (ch == 0x0D)
	{
		ch = [self readChar];
		if (ch != 0x0A)
			[self unreadChar:ch];
		ch = '\n';
	}
	*charSizePtr = charSize;
	return ch;
}

/* readChar
 * Read one character from the buffer, refilling the buffer from the file
 * if necessary.
 */
-(char)readChar
{
	if (pushedChar)
	{
		char ch = pushedChar;
		pushedChar = 0;
		return ch;
	}
	if (bufferIndex == bytesInBuffer)
	{
		buffer = [fileHandle readDataOfLength:BF_BUFFER_MAX];
		bytesInBuffer = [buffer length];
		bufferIndex = 0;
		if (bytesInBuffer == 0)
			return 0;
	}
	++readSoFar;
	return ((char *)[buffer bytes])[bufferIndex++];
}

/* unreadChar
 * Push back a character so that the next readChar returns it
 */
-(void)unreadChar:(char)ch
{
	NSAssert(pushedChar == 0, @"Cannot push back more than one character with unreadChar");
	pushedChar = ch;
}

/* close
 * Closes the buffered file
 */
-(void)close
{
	NSAssert(fileHandle != nil, @"Attempting to close an unopened file");
	[fileHandle closeFile];
	fileHandle = nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	if (fileHandle != nil)
	{
		[fileHandle closeFile];
		fileHandle = nil;
	}
	[super dealloc];
}
@end
