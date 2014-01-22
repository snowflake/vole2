//
//  Profile.m
//  Vienna
//
//  Created by Steve on 11/24/04.
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

#import "Profile.h"
#import "PreferenceNames.h"
#import "AppController.h"
#import "StringExtensions.h"

// Private functions
@interface Profile (Private)
	-(void)updateUI;
@end

@implementation Profile

/* initWithDatabase
 * Initialise the window.
 */
-(id)initWithDatabase:(Database *)theDb
{
	db = theDb;
	return [super initWithWindowNibName:@"ProfileWindow"];
}

/* windowDidLoad
 * First time window load initialisation.
 */
-(void)windowDidLoad
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_PlainTextFont];
	NSFont * plainTextFont = [NSUnarchiver unarchiveObjectWithData:fontData];
	[personResume setFont:plainTextFont];
// atatic analyser complains about this
	// [plainTextFont release];

	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"profileWindow"];
}

-(VPerson *)currentPerson
{
	return currentPerson;
}

/* setCurrentPerson
 * Updates the profile window to show the details for the specified
 * person.
 */
-(void)setCurrentPerson:(VPerson *)newPerson
{
	[newPerson retain];
	[currentPerson release];
	currentPerson = newPerson;
	[self updateUI];
}

/* pictureUpdated
 * An image was dragged onto the picture window, save it.
 */
-(IBAction)pictureUpdated:(id)sender
{
    // Get dropped image and save it.
    (void)sender;
	NSData * TIFFData = [[personImage image] TIFFRepresentationUsingCompression: NSTIFFCompressionLZW factor: 1.0];
	NSImage * newImage = [[NSImage alloc] initWithData:TIFFData];
	[currentPerson setPicture:newImage];
	if (newImage != nil)
		[noImageText setHidden:YES];
	[newImage release];
}

/* updateUI
 * Update the UI with the details of the specified person.
 */
-(void)updateUI
{
	if (currentPerson == nil)
	{
		[personName setStringValue:@""];
		[personFullName setStringValue:@""];
		[personEmailAddress setStringValue:@""];
		[personResume setString:@""];
		[personImage setImage:nil];
		[noResumeText setHidden:YES];
		[updateButton setEnabled:NO];
		[sendMailButton setEnabled:NO];
	}
	else
	{
		[personName setStringValue:[currentPerson shortName]];
		[personFullName setStringValue:[currentPerson name]];
		[personEmailAddress setStringValue:[currentPerson emailAddress]];

		// Use the application formatter to format the resume text into a nice block with
		// URLs highlighted.
		if ([currentPerson personId] == -1)
		{
			[personResume setString:@""];
			[noResumeText setHidden:NO];
			if ([[NSApp delegate] onlineMode])
			{
				[db addTask:MA_TaskCode_GetResume actionData:[currentPerson shortName] folderName:@"" orderCode:MA_OrderCode_GetResume];
				[noResumeText setStringValue:NSLocalizedString(@"Retrieving profile...", nil)];
			}
			else if ([db findTask:MA_TaskCode_GetResume wantedActionData:[currentPerson shortName]])
				[noResumeText setStringValue:NSLocalizedString(@"Latest profile will be retrieved on next connect", nil)];
			else
				[noResumeText setStringValue:NSLocalizedString(@"Select Update to retrieve profile", nil)];
		}
		else
		{
			[noResumeText setHidden:YES];
			NSAttributedString * attrText = [currentPerson info] ? [[NSApp delegate] formatMessage:[currentPerson parsedInfo] usePlainText:YES] : nil;
			[[personResume textStorage] setAttributedString:attrText];
		//  static analyser complains here
			// [attrText release];
		}

		// Set the image
		if ([currentPerson picture] == nil)
		{
			[personImage setImage:nil];
			[noImageText setHidden:NO];
		}
		else
		{
			NSImageRep * rep = [[currentPerson picture] bestRepresentationForDevice:nil];	
			NSSize size;
			size.width = [rep pixelsWide];
			size.height = [rep pixelsHigh];
			[[currentPerson picture] setSize:size];
			[noImageText setHidden:YES];
			[personImage setImage:[currentPerson picture]];
		}
		
		// Allow updates because there's something to update.
		[updateButton setEnabled:YES];
		[sendMailButton setEnabled:[[currentPerson emailAddress] hasCharacter:'@']];
	}
}

/* sendMail
 * Send e-mail to the person whose profile is displayed.
 */
-(IBAction)sendMail:(id)sender
{
    (void)sender;
	NSURL * mailURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"mailto:%@", [currentPerson emailAddress]]];
	[[NSWorkspace sharedWorkspace] openURL:mailURL];
}

/* updateResume
 * Create a task action to update the current profile.
 */
-(IBAction)updateResume:(id)sender
{
    (void)sender;
	NSAssert(db != nil, @"Forgot to initialise db before calling updateResume");
	NSAssert(currentPerson != nil, @"Update button should be disabled if currentPerson is nil");
	[db addTask:MA_TaskCode_GetResume actionData:[currentPerson shortName] folderName:@"" orderCode:MA_OrderCode_GetResume];
	[self updateUI];
}

/* dealloc
 * Clean up at the end
 */
-(void)dealloc
{
	[currentPerson release];
	[super dealloc];
}
@end
