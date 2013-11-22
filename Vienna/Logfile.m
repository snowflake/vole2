//
//  Logfile.m
//  Vienna
//
//  Created by Patrick Caulfield on 18/09/2005.
//  Copyright 2005 Patrick Caulfield. All rights reserved.
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

#import "Logfile.h"

@implementation Logfile

-(id)initWithName:(NSString *)filename versions:(NSInteger)versions
{
	if (versions == 0)
		return self;
	
	baseName = [NSString stringWithFormat: @"%@/%@", [@"~/Library/Vienna/" stringByExpandingTildeInPath], filename];
	maxVersions = versions;
	
	NSString * logfileName = [self makeFilename: @"tmp"];
	
	[[NSFileManager defaultManager] createFileAtPath: logfileName contents:nil attributes:nil];
	logfileHandle = [NSFileHandle fileHandleForWritingAtPath: logfileName];
	
	return self;
}

-(void)write:(char *)text length:(NSInteger)len
{
	if (maxVersions == 0)
		return;
	
	NSData *data = [NSData dataWithBytes: text length:len];
	
	[logfileHandle writeData: data];
}

-(void)close
{
	if (maxVersions == 0)
		return;

	[logfileHandle closeFile];
	[self purgeVersions];
}

// Get the filename with its version appended
-(NSString *)makeFilename:(NSString *)suffix
{
	return [baseName stringByAppendingPathExtension: suffix];
}

-(void)purgeVersions
{
	NSInteger i;
	NSString *oldVersion;
	NSString *newVersion;
	NSFileManager *fm = [NSFileManager defaultManager];

	// Get rid of oldest version;
#warning 64BIT: Check formatting arguments
	NSString *oldNum = [NSString stringWithFormat:@"%03d", maxVersions];
	oldVersion = [self makeFilename: oldNum];
	[fm removeFileAtPath: oldVersion handler:nil];
		
    // Move the rest up
	for (i=maxVersions-1; i>0; i--)
	{
#warning 64BIT: Check formatting arguments
		NSString *oldNum = [NSString stringWithFormat:@"%03d", i];
#warning 64BIT: Check formatting arguments
		NSString *newNum = [NSString stringWithFormat:@"%03d", i+1];
		
		oldVersion = [self makeFilename: oldNum];
		newVersion = [self makeFilename: newNum];
		
		[fm movePath: oldVersion toPath: newVersion handler:nil]; 
	}

	// Rename last file .log to .001
	oldVersion = [self makeFilename: @"log"];
	newVersion = [self makeFilename: @"001"];
	[fm movePath: oldVersion toPath: newVersion handler:nil]; 	
	
	// Rename .tmp to .log
	oldVersion = [self makeFilename: @"tmp"];
	newVersion = [self makeFilename: @"log"];
	[fm movePath: oldVersion toPath: newVersion handler:nil]; 	
}	

/* dealloc
* Clean up and release resources.
*/
-(void)dealloc
{
	[super dealloc];
}

@end
