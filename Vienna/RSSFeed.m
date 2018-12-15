//
//  RSSFeed.m
//  Vienna
//
//  Created by Steve on 4/23/05.
//  Copyright (c) 2004-2005 Steve Palmer. All rights reserved.
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

#import "RSSFeed.h"
#import "AppController.h"

// Private functions
@interface RSSFeed (Private)
	-(void)loadRSSFeedBundle;
	-(void)setLinkTitle;
	-(void)enableSaveButton;
	-(void)enableSubscribeButton;
@end

@implementation RSSFeed

/* initWithDatabase
 * Just init the RSS feed class.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		db = newDb;
		sourcesDict = nil;
		editFolderId = -1;
	}
	return self;
}

/* newRSSSubscription
 * Display the sheet to create a new RSS subscription.
 */
-(void)newRSSSubscription:(NSWindow *)window initialURL:(NSString *)initialURL
{
	[self loadRSSFeedBundle];

	// Load a list of sources from the RSSSources property list. The list of sources
	// is a dictionary of templates which specify how to create the source URL and a
	// display name which acts as the key. This allows us to support additional sources
	// without having to write new code.
	if (!sourcesDict)
	{
		NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
		NSString * pathToPList = [thisBundle pathForResource:@"RSSSources.plist" ofType:@""];
		if (pathToPList != nil)
		{
			sourcesDict = [NSDictionary dictionaryWithContentsOfFile:pathToPList];
			[feedSource removeAllItems];
			if (sourcesDict)
			{
				NSEnumerator *enumerator = [sourcesDict keyEnumerator];
				NSString * key;

				while ((key = [enumerator nextObject]) != nil)
					[feedSource addItemWithTitle:key];
				[feedSource setEnabled:YES];
				[feedSource selectItemWithTitle:@"URL"];
			}
		}
	}
	if (!sourcesDict)
		[feedSource setEnabled:NO];

	// Look on the pasteboard to see if there's an http:// url and, if so, prime the
	// URL field with it. A handy shortcut.
	if (initialURL != nil)
	{
		[feedURL setStringValue:initialURL];
		[feedSource selectItemWithTitle:@"URL"];
	}
	else
	{
		NSData * pboardData = [[NSPasteboard generalPasteboard] dataForType:NSStringPboardType];
		[feedURL setStringValue:@""];
		if (pboardData != nil)
		{
			// deprecated API here, DJE
//			NSString * pasteString = [NSString stringWithCString:[pboardData bytes] length:[pboardData length]];
//	replaced by  ( use ISOLatin1 encoding as it allows losses, we are only interested in an URL)
			NSString * pasteString = [[NSString alloc] initWithBytes: [pboardData bytes]
															   length: [pboardData length]
															 encoding: NSISOLatin1StringEncoding ];
// end of changes
			if (pasteString != nil && ([[pasteString lowercaseString] hasPrefix:@"http://"] || [[pasteString lowercaseString] hasPrefix:@"feed://"]))
			{
				[feedURL setStringValue:pasteString];
				[feedURL selectText:self];
				[feedSource selectItemWithTitle:@"URL"];
			}
		}
	}
	
	// Reset from the last time we used this sheet.
	[self enableSubscribeButton];
	[self setLinkTitle];
	editFolderId = -1;
	[NSApp beginSheet:newRSSFeedWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* editRSSSubscription
 * Edit an existing RSS subscription.
 */
-(void)editRSSSubscription:(NSWindow *)window folderId:(NSInteger)folderId
{
	[self loadRSSFeedBundle];

	Folder * folder = [db folderFromID:folderId];
	RSSFolder * rssFolder = [db rssFolderFromId:folderId];
	if (folder != nil && rssFolder != nil)
	{
		[editFeedURL setStringValue:[rssFolder subscriptionURL]];
		[self enableSaveButton];
		editFolderId = folderId;
		[NSApp beginSheet:editRSSFeedWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
}

/* loadRSSFeedBundle
 * Load the RSS feed bundle if not already.
 */
-(void)loadRSSFeedBundle
{
	if (!editRSSFeedWindow || !newRSSFeedWindow)
	{
		[NSBundle loadNibNamed:@"RSSFeed" owner:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:feedURL];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange2:) name:NSControlTextDidChangeNotification object:editFeedURL];
	}
}

/* doSubscribe
 * Handle the URL subscription button.
 */
-(IBAction)doSubscribe:(id)sender
{
    (void)sender;
	NSString * feedURLString = [[feedURL stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	// Format the URL based on the selected feed source.
	if (sourcesDict != nil)
	{
		NSMenuItem * feedSourceItem = [feedSource selectedItem];
		NSString * key = [feedSourceItem title];
		NSDictionary * itemDict = [sourcesDict valueForKey:key];
		NSString * linkName = [itemDict valueForKey:@"LinkTemplate"];
		if (linkName != nil)
// #warning 64BIT: Check formatting arguments
			feedURLString = [NSString stringWithFormat:linkName, feedURLString];
	}

	// Replace feed:// with http:// if necessary
	if ([feedURLString hasPrefix:@"feed://"])
		feedURLString = [NSString stringWithFormat:@"http://%@", [feedURLString substringFromIndex:7]];

	// Create the RSS folder in the database
	if ([db rssFolderFromURL:feedURLString] != nil)
	{
		NSRunAlertPanel(NSLocalizedString(@"Already subscribed title", nil),
						NSLocalizedString(@"Already subscribed body", nil),
						NSLocalizedString(@"OK", nil), nil, nil);
		return;
	}
	[db addRSSFolder:@"(Untitled Feed)" subscriptionURL:feedURLString];

	// If we're in online mode, get the feed immediately
#warning added a cast here
	if ([(AppController *)[NSApp delegate] onlineMode])
		[db addTask:MA_TaskCode_GetRSS actionData:@"" folderName:@"" orderCode:MA_OrderCode_GetRSS];

	// Close the window
	[NSApp endSheet:newRSSFeedWindow];
	[newRSSFeedWindow orderOut:self];
}

/* doSave
 * Save changes to the RSS feed information.
 */
-(IBAction)doSave:(id)sender
{
    (void)sender;
	NSString * feedURLString = [[editFeedURL stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	// Save the new information to the database
	[db setRSSFolderFeed:editFolderId subscriptionURL:feedURLString];
	
	// Close the window
	[NSApp endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* doSubscribeCancel
 * Handle the Cancel button.
 */
-(IBAction)doSubscribeCancel:(id)sender
{
    (void)sender;
	[NSApp endSheet:newRSSFeedWindow];
	[newRSSFeedWindow orderOut:self];
}

/* doEditCancel
 * Handle the Cancel button.
 */
-(IBAction)doEditCancel:(id)sender
{
    (void)sender;
	[NSApp endSheet:editRSSFeedWindow];
	[editRSSFeedWindow orderOut:self];
}

/* doLinkSourceChanged
 * Called when the user changes the selection in the popup menu.
 */
-(IBAction)doLinkSourceChanged:(id)sender
{
    (void)sender;
	[self setLinkTitle];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Subscribe button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
    (void)aNotification;
	[self enableSubscribeButton];
}

/* handleTextDidChange2 [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input fields are empty or enable it otherwise.
 */
-(void)handleTextDidChange2:(NSNotification *)aNotification
{
    (void)aNotification;
	[self enableSaveButton];
}

/* setLinkTitle
 * Set the text of the label that prompts for the link based on the source
 * that the user selected from the popup menu.
 */
-(void)setLinkTitle
{
	NSMenuItem * feedSourceItem = [feedSource selectedItem];
	NSString * linkTitleString = nil;
	bool showButton = NO;
	if (feedSourceItem != nil)
	{
		NSDictionary * itemDict = [sourcesDict valueForKey:[feedSourceItem title]];
		if (itemDict != nil)
		{
			linkTitleString = [itemDict valueForKey:@"LinkName"];
			showButton = [itemDict valueForKey:@"SiteHomePage"] != nil;
		}
	}
	if (linkTitleString == nil)
		linkTitleString = @"Link";
	[linkTitle setStringValue:[NSString stringWithFormat:@"%@:", linkTitleString]];
	[siteHomePageButton setHidden:!showButton];
}

/* doShowSiteHomePage
 */
-(void)doShowSiteHomePage:(id)sender
{
    (void)sender;
	NSMenuItem * feedSourceItem = [feedSource selectedItem];
	if (feedSourceItem != nil)
	{
		NSDictionary * itemDict = [sourcesDict valueForKey:[feedSourceItem title]];
		if (itemDict != nil)
		{
			NSString * siteHomePageURL = [itemDict valueForKey:@"SiteHomePage"];
			NSURL * url = [[NSURL alloc] initWithString:siteHomePageURL];
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
	}
}

/* enableSubscribeButton
 * Enable or disable the Subscribe button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSubscribeButton
{
	NSString * feedURLString = [feedURL stringValue];

	feedURLString = [feedURLString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[subscribeButton setEnabled:!([feedURLString isEqualToString:@""])]; // || [feedTitleString isEqualToString:@""])];
}

/* enableSaveButton
 * Enable or disable the Save button depending on whether or not there is a non-blank
 * string in the input fields.
 */
-(void)enableSaveButton
{
	NSString * feedURLString = [editFeedURL stringValue];
	
	feedURLString = [feedURLString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[saveButton setEnabled:!([feedURLString isEqualToString:@""])];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
