//
//  Credentials.m
//  Vienna
//
//  Created by Steve on Tue Apr 20 2004.
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

#import "Credentials.h"
#import "PreferenceNames.h"
#import <Security/SecKeychain.h>
#import <Security/SecKeychainItem.h>

// Private functions
@interface Credentials (Private)
	-(NSString *)getPasswordFromKeychain:(NSString *)theUsername;
@end

@implementation Credentials

/* initForService
 * Preloads the credentials for the specified service.
 */
-(id)initForService:(NSString *)theServiceName
{
	if ((self = [super init]) != nil)
	{
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		serviceName = theServiceName;
		username = [[defaults stringForKey:MAPref_Username] retain];
		password = [[self getPasswordFromKeychain:username] retain];
	}
	return self;
}

/* missingCredentials
 * Returns whether either the username or password were blank.
 */
-(BOOL)missingCredentials
{
	return [username isEqualToString:@""] || [password isEqualToString:@""];
}

/* username
 * Returns the current username.
 */
-(NSString *)username
{
	return username;
}

/* password
 * Returns the current password.
 */
-(NSString *)password
{
	return password;
}

/* getPasswordFromKeychain
 * Retrieves a password from the Keychain.
 */
-(NSString *)getPasswordFromKeychain:(NSString *)theUsername
{
    (void)theUsername;
	// Deprecated API was here DJE
	const char * cServiceName = [[NSString stringWithFormat:@"Vole:%@", serviceName] 
								 cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	// deprecated API was here dje
	const char * cUsername = [username cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	UInt32 passwordLength;
	void * passwordPtr;
	NSString * thePassword;
	OSStatus status;
	
	status = SecKeychainFindGenericPassword(NULL, strlen(cServiceName), cServiceName, strlen(cUsername), cUsername, &passwordLength, &passwordPtr, NULL);
	if (status != noErr)
		thePassword = @"";
	else
	{
		// deprecated API was here DJE
		//		thePassword = [NSString stringWithCString:passwordPtr length:passwordLength];
		// replacement here
		thePassword = [[[NSString alloc] 
							initWithBytes :passwordPtr 
								length:passwordLength 
							encoding:NSWindowsCP1252StringEncoding] autorelease];

		SecKeychainItemFreeContent(NULL, passwordPtr);
	}
	return thePassword;
}

/* setUsername
 * Update the username for the service.
 */
-(void)setUsername:(NSString *)newUsername
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:newUsername forKey:MAPref_Username];
	[newUsername retain];
	[username release];
	username = newUsername;
}

/* setPassword
 * Update the password for the service.
 */
-(void)setPassword:(NSString *)newPassword
{
	// Deprecated API was here DJE
	const char * cServiceName = [[NSString 
								  stringWithFormat:@"Vole:%@", serviceName]
								 cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	const char * cPassword = [newPassword cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	const char * cUsername = [username cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	SecKeychainItemRef itemRef;
	OSStatus status;

	[newPassword retain];
	[password release];
	password = newPassword;
	
	status = SecKeychainFindGenericPassword(NULL, strlen(cServiceName), cServiceName, strlen(cUsername), cUsername, NULL, NULL, &itemRef);
	if (status == noErr)
	{
		// Remove old password first
		SecKeychainItemDelete(itemRef);
	}
	SecKeychainAddGenericPassword(NULL, strlen(cServiceName), cServiceName, strlen(cUsername), cUsername, strlen(cPassword), cPassword, NULL);
}
@end
