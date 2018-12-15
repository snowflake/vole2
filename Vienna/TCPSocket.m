//
//  TCPSocket.m
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

#import "TCPSocket.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/uio.h>

@implementation TCPSocket

/* initWithAddress
 */
-(id)initWithAddress:(NSString *)theAddress port:(NSInteger)thePort
{
	if ((self = [super init]) != nil)
	{
		address = theAddress;
		port = thePort;
		fd = -1;
		timeout = 45;
		pushedChar = 0;
	}
	return self;
}

/* connect
 * Connect to the service
 */
-(BOOL)connect
{
	// Make sure we don't connect within a connect
	if (fd >= 0)
		return NO;

	// Create a socket for the communication
	fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd == -1)
		return NO;

	// Get the IP address of the service. We should be able to
	// check if we've got a raw IP address here and skip the
	// DNS lookup if so.
	struct hostent * hostentry;
	// DJE depreacated API found here
	//hostentry = gethostbyname([address cString]);
	// DJE replace with
	// cStringUsingEncoding will return NULL if address cannot be converted, resulting in a crash
	// This should not happen as the address is defined in Connect.m
	if( ![address canBeConvertedToEncoding:NSISOLatin1StringEncoding] )
// #warning 64BIT: Check formatting arguments
	{	NSLog(@"connection address cannot be converted to Latin1 %s line %d",__FILE__, __LINE__);
		return NO;
	}
	hostentry = gethostbyname([address cStringUsingEncoding:NSISOLatin1StringEncoding]);

	if (hostentry == NULL)
	{
		[self close];
		return NO;
	}

	// Now initiate the connection
	struct sockaddr_in server;

// #warning 64BIT: Inspect use of sizeof
	bzero(&server, sizeof(server));
	server.sin_family = hostentry->h_addrtype;
	memcpy((char *)&server.sin_addr, hostentry->h_addr, hostentry->h_length);
	server.sin_port = htons(port);
// #warning 64BIT: Inspect use of sizeof
	if (connect(fd, (struct sockaddr *)&server, sizeof(server)) < 0)
	{
		[self close];
		return NO;
	}

	// Make the socket non-blocking
	[self setNonBlocking: YES];
	
	// If we get here, we got a connection
	return YES;
}

/* dealloc
 * Clean up and release resources.
 */
@end
