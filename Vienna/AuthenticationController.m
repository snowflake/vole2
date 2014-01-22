//
//  AuthenticationController.m
//  Vienna
//
//  Created by Steve on Sat Mar 06 2004.
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

#import "AuthenticationController.h"

@implementation AuthenticationController

/* init
 */
-(id)initWithCredentials:(Credentials *)theCredentials
{
	credentials = theCredentials;
	return [super initWithWindowNibName:@"Authentication"];
}

/* windowDidLoad
 * Populate the fields here
 */
-(void)windowDidLoad
{
	// Set the account information
	[self reloadAuthenticationInfo];
}

/* reloadAuthenticationInfo
 * Reload the controls from the authentication source
 */
-(void)reloadAuthenticationInfo
{
	[username setStringValue:[credentials username]];
	[password setStringValue:[credentials password]];
}

/* doCancel
 * Just ignore everything and exit
 */
-(IBAction)doCancel:(id)sender
{
    (void)sender;
	[NSApp abortModal];
	[self close];
}

/* doConnect
 * Trigger a connect with the new authentication information
 */
-(IBAction)doConnect:(id)sender
{
    (void)sender;
	NSString * newUsername = [username stringValue];
	NSString * newPassword = [password stringValue];
	
	// Set the account information
	[credentials setUsername:newUsername];
	[credentials setPassword:newPassword];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_PreferencesUpdated" object:nil];
	
	[NSApp stopModal];
	[self close];
}

@end
