//
//  SSHSocket.m
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
#import "SSHSocket.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <util.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/uio.h>

@implementation SSHSocket

/* initWithAddress
 */
-(id)initWithAddress:(NSString *)theAddress port:(NSInteger)thePort
{
	if ((self = [super init]) != nil)
	{
		address = theAddress;
		port = thePort;
		timeout = 45;
		pushedChar = 0;
		fd = -1;
		sshTask = nil;
	}
	return self;
}

/* connect
 * Connect to the service
 */
-(BOOL)connect
{
	// Make sure we don't connect within a connect
	if (sshTask != nil)
		return NO;
	
	// ssh seems to much prefer ptys to pipes
	int masterFd, slaveFd;
	NSFileHandle *slaveFh;

	if (openpty(&masterFd, &slaveFd, NULL, NULL, NULL))
		return NO;

	slaveFh = [[NSFileHandle alloc] initWithFileDescriptor: slaveFd];
	
	// Now initiate the connection
	sshTask = [[NSTask alloc] init];
	[sshTask setLaunchPath: @"/usr/bin/ssh"];
	[sshTask setArguments: [NSArray arrayWithObjects: @"-l", @"qix",  @"-t", @"-e", @"none", @"-oStrictHostKeyChecking=no", address, nil]];
	[sshTask setStandardOutput: slaveFh];
	[sshTask setStandardInput: slaveFh];

	[sshTask launch];

	// These belong to the child process now.
	close(slaveFd);
	[slaveFh release];

	fd = masterFd;

	// Make the socket non-blocking
	[self setNonBlocking: YES];
			
	// If we get here, we got a connection
	return YES;
}


/* close
 * Close any open socket connection
 */
-(void)close
{
	close(fd);
	kill([sshTask processIdentifier], SIGTERM);
	[sshTask waitUntilExit];
	[sshTask release];
	sshTask = nil;
	[super close];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[sshTask release];
	[super dealloc];
}
@end
