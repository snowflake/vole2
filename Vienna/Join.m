//
//  Join.m
//  Vienna
//
//  Created by Steve on Mon Apr 12 2004.
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

#import "Join.h"

@interface Join (Private)
	-(void)enableJoinButton;
	-(void)handleTextDidChange:(NSNotification *)aNotification;
@end

@implementation Join

/* initWithDatabase
 * Just init the Join class.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
		db = newDb;
	return self;
}

/* joinCIXConference
 * Display the sheet to join a CIX conference.
 */
-(void)joinCIXConference:(NSWindow *)window initialConferenceName:(NSString *)initialConferenceName
{
	if (!joinConferenceWindow)
	{
		[NSBundle loadNibNamed:@"JoinWindow" owner:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:inputField];
	}
	
	// Provide a default name if one is specified
	if (initialConferenceName != nil)
		[inputField setStringValue:initialConferenceName];
	
	// Reset from the last time we used this sheet.
	[self enableJoinButton];
	[NSApp beginSheet:joinConferenceWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* doJoin
 * Handle the Join button.
 */
-(IBAction)doJoin:(id)sender
{
	NSString * folderPath = [[inputField stringValue] lowercaseString];
	folderPath = [folderPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([folderPath isEqualToString:@""])
		NSBeep();
	else
	{
		// Create a task to join the conference
		[db addTask:MA_TaskCode_JoinFolder actionData:@"" folderName:folderPath orderCode:MA_OrderCode_JoinFolder];

		// Close the window
		[NSApp endSheet:joinConferenceWindow];
		[joinConferenceWindow orderOut:self];
	}
}

/* doCancel
 * Handle the Cancel button.
 */
-(IBAction)doCancel:(id)sender
{
	// Close the window
	[NSApp endSheet:joinConferenceWindow];
	[joinConferenceWindow orderOut:self];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Join button if the input field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableJoinButton];
}

/* enableJoinButton
 * Enable or disable the Join button depending on whether or not there is a non-blank
 * string in the input field.
 */
-(void)enableJoinButton
{
	NSString * folderPath = [inputField stringValue];
	folderPath = [folderPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[joinButton setEnabled:![folderPath isEqualToString:@""]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[db release];
	[super dealloc];
}
@end
