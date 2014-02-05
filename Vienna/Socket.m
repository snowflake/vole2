//
//  Socket.m
//  Vienna
//
//  Created by Christine on Sun Mar 27 2005, based on TCPsocket.m
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
#import "Socket.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <util.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/uio.h>

#import "sanitise_string.h"
// increased 5/2/2014
#define BF_LINE_MAX			30000
#define BF_STRING_MAX		5120

@implementation Socket

/* init
 * Initialize the class
 */
-(id)init
{
	address = nil;
	port = -1;
	logFile = nil;
	return self;
}

-(id)initWithAddress:(NSString *)theAddress port:(NSInteger)thePort
{
	if ((self = [super init]) != nil)
	{
		address = theAddress;
		port = thePort;
	}
	return self;
}

-(void)setLogFile:(NSString *)name versions:(int)versions
{
	logFile = [[Logfile alloc] initWithName:name versions: versions];
}

-(int)getFd
{
	return fd;
}

/* address
 * Returns the connection address
 */
-(NSString *)address
{
	return address;
}

/* port
 * Return the current port number.
 */
-(int)port
{
	return port;
}

/* setTimeout
 * Change the timeout and returns the previous
 * timeout value.
 */
-(int)setTimeout:(int)newTimeout
{
	NSInteger oldTimeout = timeout;
	timeout = newTimeout;
	return oldTimeout;
}

/* sendStringWithFormat
 * Formats and sends the specified string.
 */
-(BOOL)sendStringWithFormat:(NSString *)format, ...
{
	NSString * stringToSend;
	va_list arguments;
	BOOL sendResult;

	va_start(arguments, format);
// #warning 64BIT: Check formatting arguments
	stringToSend = [[NSString alloc] initWithFormat:format arguments:arguments];
	sendResult = [self sendString:stringToSend];
	[stringToSend release];
	va_end(arguments);
	return sendResult;
}

/* sendLine
 * Sends the specified string followed by a newline.
 */
-(BOOL)sendLine:(NSString *)stringToSend
{
	BOOL sendResult;

	sendResult = [self sendString:stringToSend];
	sendResult = sendResult && [self sendString:@"\n"];
	return sendResult;
}

/* sendString
 * Sends the specified string.
 */
-(BOOL)sendString:(NSString *)stringToSend
{
	NSInteger length = [stringToSend length];
	
	// DJE use CP1252 encoding
	const char * stringBytes = (char *)[stringToSend cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	return [self sendBytes:stringBytes length:length];
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

// #warning 64BIT: Inspect use of sizeof
	*endOfFile = ![self readData:&ch length:sizeof(ch)];
	count = 0;
	while (!*endOfFile && ch != 0x0D && ch != 0x0A)
	{
		lineBuffer[count++] = ch;
		if (count == BF_LINE_MAX-1)
		{
			lineBuffer[count] = '\0';
			// deprecated API was here
			sanitise_string(lineBuffer);
			[lineString appendString:[NSString stringWithCString:lineBuffer encoding: NSWindowsCP1252StringEncoding]];
			count = 0;
		}
// #warning 64BIT: Inspect use of sizeof
		*endOfFile = ![self readData:&ch length:sizeof(ch)];
	}

	// Handle all possible line endings
	if (!*endOfFile) {
		if (ch == 0x0D)
		{
// #warning 64BIT: Inspect use of sizeof
			if ([self readData:&ch length:sizeof(ch)] && ch != 0x0A)
				[self unreadChar:ch];
		}
		else if (ch == 0x0A)
		{
// #warning 64BIT: Inspect use of sizeof
			if ([self readData:&ch length:sizeof(ch)] && ch != 0x0D)
				[self unreadChar:ch];
		}

		lineBuffer[count++] = '\n';
		lineBuffer[count] = '\0';
		sanitise_string(lineBuffer);
		[lineString appendString:[NSString stringWithCString:lineBuffer encoding:NSWindowsCP1252StringEncoding]];
	}
	return lineString;
}

/* readChar
 * Read one character from the buffer, refilling the buffer from the file
 * if necessary.
 */
-(char)readChar:(BOOL *)endOfFile
{
	char ch;
	
// #warning 64BIT: Inspect use of sizeof
	if ([self readData:&ch length:sizeof(ch)])
	{
		*endOfFile = NO;
		return ch;
	}
	*endOfFile = YES;
	return -1;
}


/* unreadChar
 * Push back a character so that the next readChar returns it
 */
-(void)unreadChar:(char)ch
{
	NSAssert(pushedChar == 0, @"Cannot push back more than one character with unreadChar");
	pushedChar = ch;
}

/* readDataOfLength
* Reads length characters from the socket.
*/
-(NSString *)readDataOfLength:(BOOL *)endOfFile length:(int)length
{
	char * data = malloc(length + 1);
	NSString * string = nil;
	
	*endOfFile = YES;
	if (data != NULL)
	{
		if ([self readData:data length:length])
		{
			*endOfFile = NO;
			// DJE depreated API here
			// string = [NSString stringWithCString:data length:length]
			//	;
			// DJE Replace with:
			sanitise_string(data);
			string= [[[NSString alloc] initWithBytes:(data) 
											  length:(length)
											encoding:NSWindowsCP1252StringEncoding ] autorelease];
			

		}
		free(data);
	}
	return string;
}

/* isConnected
 * Returns whether or not we're connected.
 */
-(BOOL)isConnected
{
	return fd != -1;
}

// Can't connect a base socket type
-(BOOL)connect
{
	return NO;
}



/* sendBytes
 * Writes the specified bytes to the socket.
 */
-(BOOL)sendBytes:(const char *)data length:(int)length
{
	NSInteger bytesWritten = 0;
	NSInteger bytesSoFar = 0;

	while (bytesSoFar < length)
	{
		if ((bytesWritten = write(fd, data + bytesSoFar, length - bytesSoFar)) == -1)
		{
			if (errno == EAGAIN)
			{
				fd_set fdset;
				struct timeval timeStruct;
				NSInteger value;

				FD_ZERO(&fdset);
				FD_SET(fd, &fdset);
				timeStruct.tv_sec = 1;
				timeStruct.tv_usec = 0;
				value = select(fd + 1, NULL, &fdset, NULL, &timeStruct);
				if (value <= 0)
					break;
				if (value > 0)
				{
					bytesWritten = write(fd, data + bytesSoFar, length - bytesSoFar);
					bytesSoFar += bytesWritten;
				}
			}
			else
				break;
		}
		else
		{
			bytesSoFar += bytesWritten;
		}
	}
	return bytesWritten == length;
}


/* peekChar
 * Peek at the next character in the input stream but
 * do not scan past it. The next read will return this
 * character. If there's no more characters waiting then
 * return -1.
 */
-(char)peekChar
{
	if (pushedChar)
		return pushedChar;
	
	char ch;
	if (read(fd, &ch, sizeof(char)) == sizeof(char))
	{
		[self unreadChar:ch];
		return ch;
	}
	return -1;
}

/* readData
 * Read a data block of the specified length
 */
-(BOOL)readData:(char *)dataBlock length:(int)length
{
	BOOL endOfFile = NO;
	NSInteger bytesReadSoFar = 0;
	NSInteger bytesRead;

	if (pushedChar)
	{
		*dataBlock = pushedChar;
		pushedChar = 0;
		++bytesReadSoFar;
	}
	
	while (!endOfFile && bytesReadSoFar < length)
	{
		if ((bytesRead = read(fd, dataBlock + bytesReadSoFar, length - bytesReadSoFar)) == -1)
		{
			if (errno == EAGAIN)
			{
				fd_set fdset;
				struct timeval timeStruct;
				NSInteger value;

				FD_ZERO(&fdset);
				FD_SET(fd, &fdset);
				timeStruct.tv_sec = timeout;
				timeStruct.tv_usec = 0;
				value = select(fd + 1, &fdset, NULL, NULL, &timeStruct);
				if (value <= 0)
					endOfFile = YES;
				else if (value > 0)
				{
					if ((bytesRead = read(fd, dataBlock + bytesReadSoFar, length - bytesReadSoFar)) == -1)
						endOfFile = YES;
					else
						bytesReadSoFar += bytesRead;
				}
			}
			else
				endOfFile = YES;
		}
		else if (bytesRead == 0)
		{
			// The remote server closed the connection. Ouch!
			endOfFile = YES;
			[self close];
		}
		else
		{
			bytesReadSoFar += bytesRead;
		}
	}
	if (logFile && !endOfFile)
		[logFile write:dataBlock length:length];
	return !endOfFile;
}

-(void)setNonBlocking:(BOOL)yesno
{
	NSInteger blockFlag = yesno==YES?1:0;
	
	if (ioctl(fd, FIONBIO, &blockFlag))
		NSLog(@"Failed to set socket to %sblocking\n", blockFlag?"":"non");
}

/* close
 * Close any open socket connection
 */
-(void)close
{
	if (fd >= 0)
	{
		close(fd);
		fd = -1;
	}
	
	if (logFile)
	{
		[logFile close];
		[logFile release];
		logFile = nil;
	}
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[address release];
	[super dealloc];
}
@end
