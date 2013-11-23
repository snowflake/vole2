//
//  AppController.m
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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
#import "AppController.h"
#import "PreferenceController.h"
#import "PreferenceNames.h"
#import "AuthenticationController.h"
#import "FoldersTree.h"
#import "Import.h"
#import "Export.h"
#import "MissingMessagesController.h"
#import "StringExtensions.h"
#import "ImageAndTextCell.h"
#import "MessageWindow.h"
#import "MessageView.h"
#import "MessageInfoBar.h"
#import "FolderHeaderBar.h"
#import "Browser.h"
#import "CheckForUpdates.h"
#import "SearchFolder.h"
#import "RSSFeed.h"
#import "PersonManager.h"
#import "SplitViewExtensions.h"
#import "Growl/GrowlApplicationBridge.h"
#import "Growl/GrowlDefines.h"
#import "WebKit/WebPreferences.h"
#import "SystemConfiguration/SCNetworkReachability.h"
#import "LogRect.h"

// Non-class function used for sorting
NSInteger messageSortHandler(id item1, id item2, void * context);

extern char * cixLocation_cstring; // in main.m
extern NSInteger cixbetaflag; // in main.m
extern char * volecixbetaname;

static NSString * MA_DefaultDatabaseName = @"~/Library/Vienna/database3.db";
static NSString * MA_DefaultMugshotsFolder = @"~/Library/Vienna/Mugshots";

#define GROWL_NOTIFICATION_DEFAULT @"NotificationDefault"

// How to select a message after reloading a folder
// (Values must be <= 0 because > 0 is a message number)
#define MA_Select_None		0
#define MA_Select_Unread	-1
#define MA_Select_Priority  -2

// Mugshot window size defaults
#define MUGSHOTS_DISABLED_SIZE  25
#define MUGSHOTS_DEFAULT_SIZE  215

@implementation AppController

/* initialize
 * Application initialization.
 */
+(void)initialize
{
	// Set the preference defaults
	NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
	NSNumber * cachedFolderID = [NSNumber numberWithLong:(long)MA_Conference_NodeID];
	NSData * msgListFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Lucida Grande" size:12.0]];
	NSData * folderFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]];
	NSData * messageFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:14.0]];
	NSData * plainTextFont = [NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Monaco" size:10.0]];
	NSData * quoteColourAsData = [NSArchiver archivedDataWithRootObject:[NSColor blueColor]];
	NSData * priorityColourAsData = [NSArchiver archivedDataWithRootObject:[NSColor redColor]];
	NSData * ignoredColourAsData = [NSArchiver archivedDataWithRootObject:[NSColor grayColor]];
	NSNumber * boolNo = [NSNumber numberWithBool:NO];
	NSNumber * boolYes = [NSNumber numberWithBool:YES];

	[defaultValues setObject:@"" forKey:MAPref_Username];
	[defaultValues setObject:MA_DefaultDatabaseName forKey:MAPref_DefaultDatabase];
	[defaultValues setObject:msgListFont forKey:MAPref_MessageListFont];
	[defaultValues setObject:messageFont forKey:MAPref_MessageFont];
	[defaultValues setObject:folderFont forKey:MAPref_FolderFont];
	[defaultValues setObject:plainTextFont forKey:MAPref_PlainTextFont];
	[defaultValues setObject:boolNo forKey:MAPref_ShowThreading];
	[defaultValues setObject:boolNo forKey:MAPref_ShowPlainText];
	[defaultValues setObject:boolNo forKey:MAPref_ShowWindowsCP];
	[defaultValues setObject:boolNo forKey:MAPref_HideIgnoredMessages];
	[defaultValues setObject:boolNo forKey:MAPref_CheckForUpdatesOnStartup];
	[defaultValues setObject:cachedFolderID forKey:MAPref_CachedFolderID];
	[defaultValues setObject:quoteColourAsData forKey:MAPref_QuoteColour];
	[defaultValues setObject:priorityColourAsData forKey:MAPref_PriorityColour];
	[defaultValues setObject:ignoredColourAsData forKey:MAPref_IgnoredColour];
	[defaultValues setObject:[NSNumber numberWithLong:(long)1] forKey:MAPref_SortDirection];
	[defaultValues setObject:MA_Column_MessageId forKey:MAPref_SortColumn];
	[defaultValues setObject:[NSNumber numberWithLong:(long)0] forKey:MAPref_CheckFrequency];
	[defaultValues setObject:NSLocalizedString(@"None", nil) forKey:MAPref_DefaultSignature];
	[defaultValues setObject:[NSArray arrayWithObjects:nil] forKey:MAPref_MessageColumns];
	[defaultValues setObject:[NSNumber numberWithLong:(long)100] forKey:MAPref_RecentOnJoin];
	[defaultValues setObject:boolYes forKey:MAPref_AutoCollapseFolders];
	[defaultValues setObject:boolNo forKey:MAPref_OnlineMode];
	[defaultValues setObject:boolNo forKey:MAPref_Recovery];
	[defaultValues setObject:boolYes forKey:MAPref_MugshotsEnabled];
	[defaultValues setObject:MA_DefaultMugshotsFolder forKey:MAPref_MugshotsFolder];
	[defaultValues setObject:[NSNumber numberWithLong:(long)MUGSHOTS_DEFAULT_SIZE] forKey:MAPref_MugshotsSize];
	[defaultValues setObject:@"~/" forKey:MAPref_DownloadFolder];
	[defaultValues setObject:boolYes forKey:MAPref_DetectMugshotDownload];
	[defaultValues setObject:@"~/Library/Vienna" forKey:MAPref_LibraryFolder];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

/* awakeFromNib
 * When we launch, we have to get our NSToolbar set up.  This involves creating a new one, adding the NSToolbarItems,
 * and installing the toolbar in our window.
 */
-(void)awakeFromNib
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// Find out who we are. The localised info in InfoStrings.plist allow
	// changing the app name if so desired.
	NSBundle * appBundle = [NSBundle mainBundle];
	appName = nil;
	if (appBundle != nil)
	{
		NSDictionary * fileAttributes = [appBundle localizedInfoDictionary];
		appName = [fileAttributes objectForKey:@"CFBundleName"];
	}
	if (appName == nil)
		appName = @"Vole";  // DJE 23/02/2013
	
	[self readAcronyms];
	
	// Create a credentials object for CIX
	cixCredentials = [[Credentials alloc] initForService:@"CIX"];
	
	// Create the toolbar.
    NSToolbar * toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MA_Toolbar"] autorelease];

    // Set the appropriate toolbar options. We are the delegate, customization is allowed,
	// changes made by the user are automatically saved and we start in icon+text mode.
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES]; 
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

    [mainWindow setToolbar:toolbar];
	[mainWindow setDelegate:self];
	[mainWindow setTitle:appName];
	[NSApp setDelegate:self];

	// Register a bunch of notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderSelection:) name:@"MA_Notify_FolderSelectionChange" object:nil];
	[nc addObserver:self selector:@selector(handleQuoteColourChange:) name:@"MA_Notify_QuoteColourChange" object:nil];
	[nc addObserver:self selector:@selector(handlePriorityColourChange:) name:@"MA_Notify_PriorityColourChange" object:nil];
	[nc addObserver:self selector:@selector(handleIgnoredColourChange:) name:@"MA_Notify_IgnoredColourChange" object:nil];
	[nc addObserver:self selector:@selector(handleMessageListFontChange:) name:@"MA_Notify_MessageListFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleMessageFontChange:) name:@"MA_Notify_MessageFontChange" object:nil];
	[nc addObserver:self selector:@selector(handleCheckFrequencyChange:) name:@"MA_Notify_CheckFrequencyChange" object:nil];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
	[nc addObserver:self selector:@selector(handleUsernameChange:) name:@"MA_Notify_UsernameChange" object:nil];
	[nc addObserver:self selector:@selector(checkForUpdatesComplete:) name:@"MA_Notify_UpdateCheckCompleted" object:nil];
	[nc addObserver:self selector:@selector(handleTaskAdded:) name:@"MA_Notify_TaskAdded" object:nil];
	[nc addObserver:self selector:@selector(handleTaskAdded:) name:@"MA_Notify_TaskChanged" object:nil];
	[nc addObserver:self selector:@selector(handleMugshotFolderChanged:) name:@"MA_Notify_MugshotsFolderChanged" object:nil];
	[nc addObserver:self selector:@selector(handlePersonUpdate:) name:@"MA_Notify_PersonUpdated" object:nil];	
	[nc addObserver:self selector:@selector(handleEditFolder:) name:@"MA_Notify_EditFolder" object:nil];

	// Hide the spinner when it is stopped
	progressCount = 0;
	[spinner setDisplayedWhenStopped:NO];

	// Show initial message count
	statusText = nil;
	[self updateStatusMessage];

	// Read some options
	showThreading = [defaults boolForKey:MAPref_ShowThreading];
	showPlainText = [defaults boolForKey:MAPref_ShowPlainText];
	showWindowsCP =  YES ; // DJE [defaults boolForKey:MAPref_ShowWindowsCP];
	showMugshots = [defaults boolForKey:MAPref_MugshotsEnabled];
	hideIgnoredMessages = [defaults boolForKey:MAPref_HideIgnoredMessages];
	reinstateThreading = NO;
	sortedFlag = YES;
	
	// Initialize the database
	db = [[Database alloc] init];
	if (![db initDatabase:[defaults stringForKey:MAPref_DefaultDatabase]])
	{
		[NSApp terminate:nil];
		return;
	}
	[db setUsername:[defaults stringForKey:MAPref_Username]];

	// Initialise our Person Manager
	personManager = [[PersonManager alloc] initWithDatabase:db];
	
	// Make ourselves a date formatter. Useful for many things except stirring soup.
	extDateFormatter = [[ExtDateFormatter alloc] init];

	// Initialize the message list
	[self initTableView];

	// Initialize the Sort By and Columns menu
	[self initSortMenu];
	[self initColumnsMenu];

	// Restore the splitview layout
	[splitView1 loadLayoutWithName:@"SplitView1Positions"];
	[splitView2 loadLayoutWithName:@"SplitView2Positions"];
	[splitView3 loadLayoutWithName:@"SplitView3Positions"];
	
	// Load the conference list from the database
	[foldersTree setDatabase:db];
	[foldersTree reloadDatabase];
	
	// Dictionary for initWithHTML
	[self updateHTMLDict];

	// Create a backtrack array
	isBacktracking = NO;
	selectAtEndOfReload = MA_Select_Unread;
	backtrackArray = [[BackTrackArray alloc] init];
	
	// Retrieve the colour of quotes text in messages
	[self handleQuoteColourChange:nil];
	[self handlePriorityColourChange:nil];
	[self handleIgnoredColourChange:nil];

	// Select the first conference
	NSInteger previousFolderId = [defaults integerForKey:MAPref_CachedFolderID];
	if (![foldersTree selectFolder:previousFolderId])
		[foldersTree selectFolder:[db conferenceNodeID]];

	// Create the activity window
	// We call the window function to cause the NIB file to be loaded now
	// so that logged activity goes to the textView window. If we didn't
	// do this, the textView control would be nil and opening the activity
	// window after a connect started would show a truncated or empty log.
	activityViewer = [[ActivityViewer alloc] init];
	[activityViewer window];

	// Make the search control the next key view of the message viewer
	[textView setNextKeyView:searchView];
	[searchView setNextKeyView:[foldersTree outlineView]];

	// Preload Out Basket and Draft folders so their folder status
	// is correct.
	[db initMessageArray:[db folderFromID:MA_Outbox_NodeID]];
	[db initMessageArray:[db folderFromID:MA_Draft_NodeID]];

	// Show the current unread priority count
	originalIcon = [[NSApp applicationIconImage] copy];
	lastCountOfPriorityUnread = 0;
	[self showPriorityUnreadCountOnApplicationIcon];

	// Set online mode
	isOnlineMode = [defaults integerForKey:MAPref_OnlineMode];
	batchConnect = NO;

	// Use Growl if it is installed
	growlAvailable = NO;
	[GrowlApplicationBridge setGrowlDelegate:self];

	// Start the check timer
	checkTimer = nil;
	[self handleCheckFrequencyChange:nil];
}

/* updateHTMLDict
 * Update the HTML dictionary that formatMessage uses for rendering HTML in NSTextView.
 */
-(void)updateHTMLDict
{
	[htmlDict release];
	htmlDict = [[NSMutableDictionary dictionary] retain];

	WebPreferences * webPrefs = [[WebPreferences alloc] initWithIdentifier:@"ViennaWebPrefs"];
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_MessageFont];
	NSFont * messageFont = [NSUnarchiver unarchiveObjectWithData:fontData];	

	// Set the default web family and size to whatever the user selected
	// for the message font.
	[webPrefs setStandardFontFamily:[messageFont familyName]];
	[webPrefs setDefaultFontSize:(NSInteger)[messageFont pointSize]];
	
	[htmlDict setObject:[NSNumber numberWithLong:(long)1] forKey:@"UseWebKit"];
	[htmlDict setObject:webPrefs forKey:@"WebPreferences"];
	[webPrefs release];
}

/* growlIsReady
 * Called by Growl if it is loaded. We use this as a trigger to acknowledge its existence.
 */
-(void)growlIsReady
{
	growlAvailable = YES;
}

/* registrationDictionaryForGrowl
 * Called by Growl to request the notification dictionary.
 */
-(NSDictionary *)registrationDictionaryForGrowl
{
	NSMutableArray *defNotesArray = [NSMutableArray array];
	NSMutableArray *allNotesArray = [NSMutableArray array];
	
	[allNotesArray addObject:@"New Messages"];
	[defNotesArray addObject:@"New Messages"];
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		appName, GROWL_APP_NAME, 
		allNotesArray, GROWL_NOTIFICATIONS_ALL, 
		defNotesArray, GROWL_NOTIFICATIONS_DEFAULT,
		nil];

	growlAvailable = YES;
	return regDict;
}

/* initTableView
 * Do all the initialization for the message list table view control
 */
-(void)initTableView
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// Variable initialization here
	currentFolderId = -1;
	currentArrayOfMessages = nil;
	currentSelectedRow = -1;
	requestedMessage = 0;
	messageListFont = nil;
	boldMessageListFont = nil;

	// Initialize sort to default to message number
	[self setSortColumnIdentifier:[defaults stringForKey:MAPref_SortColumn]];
	sortDirection = [defaults integerForKey:MAPref_SortDirection];
	sortColumnTag = [self tagFromIdentifier:sortColumnIdentifier];

	// Initialize the message columns from saved data
	NSArray * dataArray = [defaults arrayForKey:MAPref_MessageColumns];
	VField * field;
	NSUInteger index;
	
	for (index = 0; index < [dataArray count];)
	{
		NSString * identifier;
		NSInteger width = 100;
		BOOL visible = NO;

		identifier = [dataArray objectAtIndex:index++];
		if (index < [dataArray count])
			// #warning 64BIT dje integerValue -> intValue
			visible = [[dataArray objectAtIndex:index++] intValue] == YES;
		if (index < [dataArray count])
			// #warning 64BIT dje integerValue -> intValue
			width = [[dataArray objectAtIndex:index++] intValue];

		field = [db fieldByIdentifier:identifier];
		[field setVisible:visible];
		[field setWidth:width];
	}

	// Get the default list of visible columns
	[self updateVisibleColumns];
	
	// Set the target for double-click actions
	[messageList setDoubleAction:@selector(doubleClickRow:)];
	[messageList setTarget:self];
	
	// Set the default fonts
	[self setTableViewFont];
}

/* initSortMenu
 * Create the sort popup menu.
 */
-(void)initSortMenu
{
	NSMenu * viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
	NSMenu * sortMenu = [[[NSMenu alloc] initWithTitle:@"Sort By"] autorelease];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	VField * field;

	while ((field = [enumerator nextObject]) != nil)
	{
		// Filter out columns we don't sort on. Later we should have an attribute in the
		// field object itself based on which columns we can sort on.
		if ([field tag] != MA_ID_MessageFolderId &&
			[field tag] != MA_ID_MessageComment &&
			[field tag] != MA_ID_MessagePriority &&
			[field tag] != MA_ID_MessageIgnored &&
			[field tag] != MA_ID_MessageText)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field title] action:@selector(doSortColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[sortMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[[viewMenu itemWithTitle:@"Sort By"] setSubmenu:sortMenu];
}

/* initColumnsMenu
 * Create the columns popup menu.
 */
-(void)initColumnsMenu
{
	NSMenu * viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
	NSMenu * columnsMenu = [[[NSMenu alloc] initWithTitle:@"Columns"] autorelease];
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	VField * field;
	
	while ((field = [enumerator nextObject]) != nil)
	{
		// Filter out columns we don't view in the message list. Later we should have an attribute in the
		// field object based on which columns are visible in the tableview.
		if ([field tag] != MA_ID_MessageText &&
			[field tag] != MA_ID_MessagePriority &&
			[field tag] != MA_ID_MessageIgnored)
		{
			NSMenuItem * menuItem = [[NSMenuItem alloc] initWithTitle:[field title] action:@selector(doViewColumn:) keyEquivalent:@""];
			[menuItem setRepresentedObject:field];
			[columnsMenu addItem:menuItem];
			[menuItem release];
		}
	}
	[[viewMenu itemWithTitle:@"Columns"] setSubmenu:columnsMenu];
}

/* showColumnsForFolder
 * Display the columns for the specific folder.
 */
-(void)showColumnsForFolder:(NSInteger)folderId
{
	if (folderId == MA_Outbox_NodeID || folderId == MA_Draft_NodeID)
	{
		NSTableColumn * tableColumn = [messageList tableColumnWithIdentifier:MA_Column_MessageFrom];
		[[tableColumn headerCell] setStringValue:NSLocalizedString(@"To", nil)];
	}
	else
	{
		NSTableColumn * tableColumn = [messageList tableColumnWithIdentifier:MA_Column_MessageFrom];
		[[tableColumn headerCell] setStringValue:NSLocalizedString(@"From", nil)];
	}
}

/* updateVisibleColumns
 * Iterates through the array of visible columns and makes them
 * visible or invisible as needed.
 */
-(void)updateVisibleColumns
{
	NSArray * fields = [db arrayOfFields];
	NSInteger count = [fields count];
	NSInteger index;

	// Get the bounds of the message list because we need to work out
	// when the columns spill beyond the bounds
	NSRect listRect = [messageList bounds];
	NSInteger widthSoFar = 0;
	NSInteger countOfResizableColumns = 0;

	// Create the new columns
	for (index = 0; index < count; ++index)
	{
		VField * field = [fields objectAtIndex:index];
		NSString * identifier = [field name];

		// Remove each column as we go.
		NSTableColumn * tableColumn = [messageList tableColumnWithIdentifier:identifier];
		if (tableColumn != nil)
		{
			[field setWidth:[tableColumn width]];
			[messageList removeTableColumn:tableColumn];
		}

		// Add to the end only those columns that are visible
		if ([field visible])
		{
			NSTableColumn * newTableColumn = [[NSTableColumn alloc] initWithIdentifier:identifier];
			NSTableHeaderCell * headerCell = [newTableColumn headerCell];
			NSInteger tag = [field tag];
			BOOL isResizable = (tag != MA_ID_MessageUnread && tag != MA_ID_MessageFlagged);

			[headerCell setTitle:[field title]];
			[newTableColumn setEditable:NO];
//			[newTableColumn setResizable:isResizable]; //PJC Deprecated in 10.4 (but only available from 10.4!)
			[newTableColumn setResizingMask: NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask];
			[newTableColumn setMinWidth:10];
			[newTableColumn setMaxWidth:1000];
			[newTableColumn setWidth:[field width]];
			[messageList addTableColumn:newTableColumn];
			[newTableColumn release];

			widthSoFar += [field width];
			if (isResizable)
				++countOfResizableColumns;
		}
	}

	// If one or more of the last columns are outside the view, do an
	// auto-resize to bring them back.
	if ((widthSoFar >= listRect.size.width) && countOfResizableColumns > 0)
	{
		NSInteger diff = (widthSoFar - listRect.size.width) / countOfResizableColumns;
		for (index = 0; index < count; ++index)
		{
			VField * field = [fields objectAtIndex:index];
			if ([field visible])
			{
				NSTableColumn * tableColumn = [messageList tableColumnWithIdentifier:[field name]];
				if ([tableColumn resizingMask] & NSTableColumnAutoresizingMask)
//				if ([tableColumn isResizable])  //PJC Deprecated in 10.4 (but only available from 10.4!)
				{
					NSInteger newFieldWidth = [field width] - diff;
					[field setWidth:newFieldWidth];
					[tableColumn setWidth:newFieldWidth];
				}
			}
		}
	}
	
	// Our folders have images next to them.
    NSTableColumn * tableColumn = [messageList tableColumnWithIdentifier:MA_Column_MessageId];
	ImageAndTextCell * imageAndTextCell = [[ImageAndTextCell alloc] init];
    [tableColumn setDataCell:imageAndTextCell];
	[imageAndTextCell release];
	
	// Set the extended date formatter on the Date column
	tableColumn = [messageList tableColumnWithIdentifier:MA_Column_MessageDate];
	[[tableColumn dataCell] setFormatter:extDateFormatter];
	
	// Set the images for specific header columns
	[messageList setHeaderImage:MA_Column_MessageUnread imageName:@"unread_header.tiff"];
	[messageList setHeaderImage:MA_Column_MessageFlagged imageName:@"flagged_header.tiff"];
	
	// Initialise the sort direction
	[self showSortDirection];	
	
	// Extend the last column
	[messageList sizeLastColumnToFit];
}

/* saveTableSettings
 * Save the table column settings, specifically the visibility and width.
 */
-(void)saveTableSettings
{
	NSArray * fields = [db arrayOfFields];
	NSEnumerator * enumerator = [fields objectEnumerator];
	VField * field;

	// An array we need for the settings
	NSMutableArray * dataArray = [[NSMutableArray alloc] init];

	// Create the new columns
	while ((field = [enumerator nextObject]) != nil)
	{
		[dataArray addObject:[field name]];
		[dataArray addObject:[NSNumber numberWithBool:[field visible]]];
		[dataArray addObject:[NSNumber numberWithLong:(long)[field width]]];
	}

	// Save these to the preferences
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:dataArray forKey:MAPref_MessageColumns];
	[defaults synchronize];
	
	// We're done
	[dataArray release];
}

/* setTableViewFont
 * Gets the font for the message list and adjusts the table view
 * row height to properly display that font.
 */
-(void)setTableViewFont
{
	NSInteger height;
	
	[messageListFont release];
	[boldMessageListFont release];
	
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_MessageListFont];
	messageListFont = [NSUnarchiver unarchiveObjectWithData:fontData];
	boldMessageListFont = [[NSFontManager sharedFontManager] convertWeight:YES ofFont:messageListFont];
	[boldMessageListFont retain ];   // DJE This makes it work on Leopard without garbage collection
	[messageListFont retain ];  // and this as well 


// deprecated API was here DJE	
#if 0
	height = [boldMessageListFont defaultLineHeightForFont];
#else
	// replacement here
	NSLayoutManager *nslm = [[NSLayoutManager alloc] init];
	height = (NSInteger) [ nslm defaultLineHeightForFont: boldMessageListFont ];
	[ nslm release];
#endif
	[messageList setRowHeight:height + 3];
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSTableColumn * sortColumn = [messageList tableColumnWithIdentifier:sortColumnIdentifier];

	if (showThreading)
	{
		[messageList setHighlightedTableColumn:nil];
		[messageList setIndicatorImage:nil inTableColumn:sortColumn];
	}
	else
	{
		NSString * imageName = (sortDirection < 0) ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator";
		[messageList setHighlightedTableColumn:sortColumn];
		[messageList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:sortColumn];
	}
}

/* showPriorityUnreadCountOnApplicationIcon
 * Update the Vienna application icon to show the number of unread priority messages.
 */
-(void)showPriorityUnreadCountOnApplicationIcon
{
	NSInteger currentCountOfPriorityUnread = [db countOfPriorityUnread];
	if (currentCountOfPriorityUnread != lastCountOfPriorityUnread)
	{
		if (currentCountOfPriorityUnread > 0)
		{
// #warning 64BIT: Check formatting arguments
			NSString *countdown = [NSString stringWithFormat:@"%li", (long)currentCountOfPriorityUnread];
			NSImage * iconImageBuffer = [originalIcon copy];
			NSSize iconSize = [originalIcon size];

			// Create attributes for drawing the count. In our case, we're drawing using in
			// 26pt Helvetica bold white.
			NSDictionary * attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica-Bold" size:26],
																					 NSFontAttributeName,
																					 [NSColor whiteColor],
																					 NSForegroundColorAttributeName,
																					 nil];
			NSSize numSize = [countdown sizeWithAttributes:attributes];

			// Create a red circle in the icon large enough to hold the count.
			[iconImageBuffer lockFocus];
			[originalIcon drawAtPoint:NSMakePoint(0, 0)
							 fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) 
							operation:NSCompositeSourceOver 
							 fraction:1.0f];
			CGFloat max = (numSize.width > numSize.height) ? numSize.width : numSize.height;
			max += 16;
			NSRect circleRect = NSMakeRect(iconSize.width - max, 0, max, max);
			NSBezierPath * bp = [NSBezierPath bezierPathWithOvalInRect:circleRect];
			[[NSColor colorWithCalibratedRed:0.8f green:0.0f blue:0.0f alpha:1.0f] set];
			[bp fill];

			// Draw the count in the red circle
			NSPoint point = NSMakePoint(NSMidX(circleRect) - numSize.width / 2.0f,  NSMidY(circleRect) - numSize.height / 2.0f + 2.0f);
			[countdown drawAtPoint:point withAttributes:attributes];

			// Now set the new app icon and clean up.
			[iconImageBuffer unlockFocus];
			[NSApp setApplicationIconImage:iconImageBuffer];
			[iconImageBuffer release];
			[attributes release];
		}
		else
			[NSApp setApplicationIconImage:originalIcon];
		lastCountOfPriorityUnread = currentCountOfPriorityUnread;
	}
}

/* isBusy
 * Return whether the client is busy processing something that cannot be interrupted by a connect or
 * any other database access.
 */
-(BOOL)isBusy
{
	BOOL isImporting = [importController isImporting] || [exportController isExporting];
	BOOL isGettingMissingMessages = [missingMessagesController isScanning];
	return isImporting || isGettingMissingMessages;
}

/* showPreferencePanel
 * Display the Preference Panel.
 */
-(IBAction)showPreferencePanel:(id)sender
{
	if (!preferenceController)
		preferenceController = [[PreferenceController alloc] initWithCredentials:cixCredentials];
	[preferenceController showWindow:self];
}

/* applicationShouldTerminate
 * This function is called when the user wants to close Vienna. First we check to see
 * if a connection or import is running and that all messages are saved.
 */
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (![self closeAllMessageWindows])
		return NSTerminateCancel;
	if ([connect isProcessing])
	{
		NSInteger returnCode;
		
		returnCode = NSRunAlertPanel(NSLocalizedString(@"Connect Running", nil),
									 NSLocalizedString(@"Connect Running text", nil),
									 NSLocalizedString(@"Quit", nil),
									 NSLocalizedString(@"Cancel", nil),
									 nil);
		if (returnCode == NSAlertAlternateReturn)
			return NSTerminateCancel;
	}
	[connect stopCIXConnectThread];
	return NSTerminateNow;
}

/* applicationWillTerminate
 * This is where we put the clean-up code.
 */
-(void)applicationWillTerminate:(NSNotification *)aNotification
{
	// Save the splitview layout
	[splitView1 storeLayoutWithName:@"SplitView1Positions"];
	[splitView2 storeLayoutWithName:@"SplitView2Positions"];
	[splitView3 storeLayoutWithName:@"SplitView3Positions"];
	
	[self saveTableSettings];
	if (currentFolderId != -1)
		[db flushFolder:currentFolderId];
	[db close];
	[connect release];
}

/* windowWillClose
 * Handle closure of the main window. If we get applicationShouldTerminateAfterLastWindowClosed working
 * (see below) then we can remove this function.
 */
-(void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:nil];
}

/* applicationShouldTerminateAfterLastWindowClosed
 * This is supposed to get called when the last window owned by the application is closed but
 * this isn't happening here. Not sure why but we need to debug this.
 */
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

/* applicationDidFinishLaunching
 * Handle post-load activities.
 */
-(void)applicationDidFinishLaunching:(NSNotification *)aNot
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// If the user's default CIX profile is missing, add an action to retrieve
	// it from CIX.
	if (![cixCredentials missingCredentials])
	{
		VPerson * person = [personManager personFromPerson:[cixCredentials username]];
		if (person == nil)
			[db addTask:MA_TaskCode_GetResume actionData:[cixCredentials username] folderName:@"" orderCode:MA_OrderCode_GetResume];
		// static analyser complains
		//[person release];
	}

	// Check for application updates silently
	if ([defaults boolForKey:MAPref_CheckForUpdatesOnStartup])
	{
		if (!checkUpdates)
			checkUpdates = [[CheckForUpdates alloc] init];
		[checkUpdates checkForUpdate:mainWindow showUI:NO];
	}
}

/* showBrowser
 * Display the browser window.
 */
-(IBAction)showBrowser:(id)sender
{
	if (browserController == nil)
		browserController = [[Browser alloc] initWithDatabase:db];
	[browserController showWindow:sender];
}

/* compactDatabase
 * Run the database compaction command.
 */
-(IBAction)compactDatabase:(id)sender
{
	[NSApp beginSheet:compactDatabaseWindow
	   modalForWindow:mainWindow 
		modalDelegate:nil 
	   didEndSelector:nil 
		  contextInfo:nil];

	[db compactDatabase];

	[NSApp endSheet:compactDatabaseWindow];
	[compactDatabaseWindow orderOut:self];
}

/* gotoMessage
 */
-(IBAction)gotoMessage:(id)sender
{
	NSNumberFormatter * formatter = [gotoNumber formatter];

	// Set the minimum and maximum range of the Goto based on the
	// minimum and maximum message number
	[formatter setMinimum:[NSDecimalNumber decimalNumberWithMantissa:1 exponent:0 isNegative:NO]];
	[formatter setMaximum:[NSDecimalNumber decimalNumberWithMantissa:999999 exponent:0 isNegative:NO]];

	// Fire up the sheet
	[NSApp beginSheet:gotoWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:nil 
		  contextInfo:nil];
}

/* endGotoMessage
 */
-(IBAction)endGotoMessage:(id)sender
{
	// #warning 64BIT dje integerValue -> intValue
	NSInteger messageNumber = [gotoNumber intValue];

	[gotoWindow orderOut:sender];
	[NSApp endSheet:gotoWindow returnCode:1];
	if (![self scrollToMessage:messageNumber])
		[self offerToRetrieveMessage:messageNumber fromFolderId:currentFolderId];
}

/* cancelGotoMessage
 */
-(IBAction)cancelGotoMessage:(id)sender
{
	[gotoWindow orderOut:sender];
	[NSApp endSheet:gotoWindow returnCode:0];
}

/* originalThread
 * From a search folder, switch to the original folder from which the selected
 * message came from.
 */
-(IBAction)originalThread:(id)sender
{
	NSInteger rowIndex = [messageList selectedRow];
	if (rowIndex != -1)
	{
		VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
		[self selectFolderAndMessage:[thisMessage folderId] messageNumber:[thisMessage messageId]];
	}
}

/* originalMessage
 * Place the selection on the message to which the current one is a comment,
 * assuming there is one.
 */
-(IBAction)originalMessage:(id)sender
{
	NSInteger rowIndex = [messageList selectedRow];
	if (rowIndex != -1)
	{
		VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
		NSInteger comment = [thisMessage comment];
		if (comment)
		{
			NSInteger folderId = [thisMessage folderId];

			if (folderId == MA_Outbox_NodeID || folderId == MA_Draft_NodeID)
				folderId = [foldersTree folderFromPath:[db conferenceNodeID] path:[thisMessage sender]];

			if (![self selectFolderAndMessage:folderId messageNumber:comment])
				[self offerToRetrieveMessage:comment fromFolderId:folderId];
		}
	}
}

/* offerToRetrieveMessage
 * If we're offline, offer to retrieve a single message from the service. If we're online,
 * retrieve the message immediately.
 */
-(void)offerToRetrieveMessage:(NSInteger)messageId fromFolderId:(NSInteger)folderId
{
	NSString * folderPath = [db folderPathName:folderId];
	Folder * folder = [db folderFromID:currentFolderId];
	if (!IsRSSFolder(folder))
	{
		if (isOnlineMode)
			[self retrieveMessage:messageId fromFolder:folderPath];
		else
		{
// #warning 64BIT: Check formatting arguments (This string is not in localizablestrings
			NSString * titleText = [NSString stringWithFormat:NSLocalizedString(@"Offer to retrieve message title", nil), messageId];
			NSString * bodyText = NSLocalizedString(@"Offer to retrieve message text", nil);
			
			// Package up the message and folder numbers to the context info
			NSArray * contextArray = [[NSArray arrayWithObjects:[NSNumber numberWithLong:(long)messageId], folderPath, nil] retain];
// #warning 64BIT: Check formatting arguments
			NSBeginAlertSheet(titleText,
							  NSLocalizedString(@"Retrieve", nil),
							  NSLocalizedString(@"Cancel", nil),
							  nil,
							  mainWindow,
							  self,
							  @selector(doRetrieveMessage:returnCode:contextInfo:),
							  nil, contextArray,
							  bodyText);
		}
	}
}

/* offerToRetrieveMessage
 * Offer to retrieve a single message from the service.
 */
-(void)offerToRetrieveMessage:(NSInteger)messageId fromFolderPath:(NSString *)folderPath
{
// #warning 64BIT: Check formatting arguments
	NSString * titleText = [NSString stringWithFormat:NSLocalizedString(@"Offer to join and retrieve message title", nil), folderPath];
// #warning 64BIT: Check formatting arguments
	NSString * bodyText = [NSString stringWithFormat:NSLocalizedString(@"Offer to join and retrieve message text", nil), folderPath];
	
	// Package up the message and folder numbers to the context info
	NSArray * contextArray = [[NSArray arrayWithObjects:[NSNumber numberWithLong:(long)messageId], folderPath, nil] retain];	
// #warning 64BIT: Check formatting arguments
	NSBeginAlertSheet(titleText,
					  NSLocalizedString(@"Join", nil),
					  NSLocalizedString(@"Cancel", nil),
					  nil,
					  mainWindow,
					  self,
					  @selector(doRetrieveMessage:returnCode:contextInfo:),
					  nil, contextArray,
					  bodyText);
}

/* doRetrieveMessage
 * Handle the response from the sheet.
 */
-(void)doRetrieveMessage:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSArray * contextArray = (NSArray *)contextInfo;
	if (returnCode == NSAlertDefaultReturn)
	{
		NSAssert(contextArray != nil, @"Got a nil context array");
		NSAssert([contextArray count] == 2, @"Context array is the wrong size");
		// #warning 64BIT dje integerValue -> intValue
		NSInteger messageId = [[contextArray objectAtIndex:0] intValue];
		NSString * folderPath = [contextArray objectAtIndex:1];
		[self retrieveMessage:messageId fromFolder:folderPath];
	}
	[contextArray release];
}

/* retrieveMessage
 * Create a task to retrieve a single message.
 */
-(void)retrieveMessage:(NSInteger)messageId fromFolder:(NSString *)folderPath
{
// #warning 64BIT: Check formatting arguments
	NSString * messageString = [NSString stringWithFormat:@"%ld", messageId];
	[db addTask:MA_TaskCode_FileMessages actionData:messageString folderName:folderPath orderCode:MA_OrderCode_FileMessages];
	
	// If we're in online mode, make a note of the requested message so we can select it
	// when the folder is refreshed unless we move to a different message or folder
	if (isOnlineMode)
		requestedMessage = messageId;
}

/* scrollToMessage
 * Moves the selection to the specified message. Returns YES if we found the
 * message, NO otherwise.
 */
-(BOOL)scrollToMessage:(NSInteger)number
{
	NSEnumerator * enumerator = [currentArrayOfMessages objectEnumerator];
	VMessage * thisMessage;
	NSInteger rowIndex = 0;
	BOOL found = NO;

	while ((thisMessage = [enumerator nextObject]) != nil)
	{
		if ([thisMessage messageId] == number)
		{
			[self makeRowSelectedAndVisible:rowIndex];
			found = YES;
			break;
		}
		++rowIndex;
	}
	requestedMessage = 0;
	return found;
}

/* printDocument
 * Print the current message in the message window.
 */
-(IBAction)printDocument:(id)sender
{
	NSPrintInfo * printInfo = [NSPrintInfo sharedPrintInfo];
	NSPrintOperation * printOp;
	
	[printInfo setVerticallyCentered:NO];
	printOp = [NSPrintOperation printOperationWithView:textView printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}

/* toggleOnline
 * Toggle online mode.
 */
-(IBAction)toggleOnline:(id)sender
{
	if (isOnlineMode)
		[self goOffline:sender];
	else
		[self goOnline:sender];
}

/* goOnline
 * Switch to online mode. Note that we should NOT connect
 * at this point. Save that for the first actual task that
 * requires a connection.
 */
-(IBAction)goOnline:(id)sender
{
	if (!isOnlineMode)
	{
		isOnlineMode = YES;
		[self beginConnect: NO];
	}
}

/* goOffline
 * Switch to offline mode. Call the connectoid to ensure
 * that we actually disconnect from the service. If we weren't
 * already connected then it should just ignore us.
 */
-(IBAction)goOffline:(id)sender
{
	if (isOnlineMode)
	{
		[connect setOnline:NO];
		isOnlineMode = NO;
	}
}

-(BOOL)networkUP
{
	Boolean success;
	BOOL okay;
	SCNetworkConnectionFlags status;
	
	success = SCNetworkCheckReachabilityByName(cixLocation_cstring, &status); //cixLocation_cstring is in main.m
	okay = success && (status & kSCNetworkFlagsReachable) && 
		!(status & kSCNetworkFlagsConnectionRequired);
	
    return okay;
}

/* beginConnect
 * Initiate a connection to the server.
 */
-(BOOL)beginConnect:(NSInteger)connectMode
{	
	if (![self networkUP])
	{
		[self setStatusMessage:NSLocalizedString(@"The network connection is not available.", nil)];
		return NO;
	}	
	
	if (connect == nil)
		connect = [[Connect alloc] initWithCredentials:cixCredentials];
	
	// If either the user name or password are blank, prompt the user
	// for something meaningful.
	while ([cixCredentials missingCredentials])
	{
		if (!authenticationController)
			authenticationController = [[AuthenticationController alloc] initWithCredentials:cixCredentials];
		[authenticationController reloadAuthenticationInfo];
		if ([NSApp runModalForWindow:[authenticationController window]] == NSRunAbortedResponse)
			return NO;
	}

	// Start with a new activity log.
	if (!isOnlineMode)
		[activityViewer clearLog];

	// Set our delegate and off we go.
	[connect setDelegate:self];
	[connect setDatabase:db];
	[connect setMode: connectMode];
	[connect setOnline:isOnlineMode];
	return YES;
}

/* handleTaskAdded
 * Called when a new task is added to the database. If we're in online mode then we
 * action this task immediately.
 */
-(void)handleTaskAdded:(NSNotification *)nc
{
	VTask * task = (VTask *)[nc object];
	if (task != nil && [task resultCode] == MA_TaskResult_Waiting && isOnlineMode && !batchConnect)
	{
		[self beginConnect: MA_ConnectMode_Both];
		[connect processSingleTask:task];
	}
}

/* folders
 * Return the array of folders.
 */
-(NSArray *)folders
{
	return [foldersTree folders:[db conferenceNodeID]];
}

/* database
 * Return the active application database object.
 */
-(Database *)database
{
	return db;
}

/* appName
 * Returns's the application friendly (localized) name.
 */
-(NSString *)appName
{
	return appName;
}

/* currentFolderId
 * Return the ID of the currently selected folder whose messages are shown in
 * the message window.
 */
-(NSInteger)currentFolderId
{
	return currentFolderId;
}

/* personManager
 * Return the active application person manager object
 */
-(PersonManager *)personManager
{
	return personManager;
}

/* onlineMode
 * Returns whether or not we're in online mode.
 */
-(BOOL)onlineMode
{
	return isOnlineMode;
}

/* fillMessageGaps
 * Begin the UI to locate and fill gaps in the current folder.
 */
-(IBAction)fillMessageGaps:(id)sender
{
	NSArray * arrayOfFolders = [foldersTree folders:[foldersTree actualSelection]];

	if (!missingMessagesController)
		missingMessagesController = [[MissingMessagesController alloc] init];
	[missingMessagesController getMissingMessages:mainWindow arrayOfFolders:arrayOfFolders database:db];
}

/* handleRSSLink
 * Handle feed://<rss> links. If we're already subscribed to the link then make the folder
 * active. Otherwise offer to subscribe to the link.
 */
-(void)handleRSSLink:(NSString *)linkPath
{
	RSSFolder * folder = [db rssFolderFromURL:linkPath];
	if (folder != nil)
		[foldersTree selectFolder:[folder folderId]];
	else
	{
		if (!rssFeed)
			rssFeed = [[RSSFeed alloc] initWithDatabase:db];
		[rssFeed newRSSSubscription:mainWindow initialURL:linkPath];
	}
}

/* handleCIXLink
 * Handles a CIX URL. Valid formats are:
 *
 *   cix:<number> ................... Selects <messagenumber> in the current folder
 *   cix:<folder>:<messagenumber> ... Selects <messagenumber> in folder <topic> which is another sub-folder of
 *                                    the current folder's parent
 *   cix:/<folder>:<messagenumber> .. Same as above
 *   cix:<folder> ................... Selects the first topic in the specified conference.
 *   cix:<folder>/<folder> .......... Parses the path to the folder and selects the last message in the folder.
 */
-(void)handleCIXLink:(NSString *)folderPath messageNumber:(NSInteger)messageNumber
{
	if (folderPath == nil)
	{
		if (messageNumber != 0)
		{
			if (![self scrollToMessage:messageNumber])
				[self offerToRetrieveMessage:messageNumber fromFolderId:currentFolderId];
		}
	}
	else
	{
		NSInteger folderId = -1;

		if ([folderPath hasPrefix:@"/"])
			folderPath = [folderPath substringFromIndex:1];
		if (![folderPath hasCharacter:'/'])
		{
			Folder * folder = [db folderFromID:currentFolderId];
			folderId = [foldersTree folderFromPath:[folder parentId] path:folderPath];
		}
		else
			folderId = [foldersTree folderFromPath:[db conferenceNodeID] path:folderPath];
		if (folderId == -1)
			[self offerToRetrieveMessage:messageNumber fromFolderPath:folderPath];
		else
		{
			folderId = [foldersTree firstChildFolder:folderId];
			[self selectFolderAndMessage:folderId messageNumber:messageNumber];
		}
	}
}

-(void)handleCIXFileLink:(NSString *)folderPath file:(NSString *)filename
{
	[db addTask:MA_TaskCode_FileDownload actionData:filename folderName:folderPath orderCode:MA_OrderCode_FileDownload];
	
#warning 64BIT: Check formatting arguments
	NSString *statusString = [NSString stringWithFormat:NSLocalizedString(@"'%@:%@' marked for download", nil),folderPath, filename];

	[self setStatusMessage:statusString];
}


/* handleEditFolder
 * Respond to an edit folder notification.
 */
-(void)handleEditFolder:(NSNotification *)nc
{
	TreeNode * node = (TreeNode *)[nc object];
	Folder * folder = [db folderFromID:[node nodeId]];
	
	if (IsRSSFolder(folder))
	{
		if (!rssFeed)
			rssFeed = [[RSSFeed alloc] initWithDatabase:db];
		[rssFeed editRSSSubscription:mainWindow folderId:[node nodeId]];
	}
	else if (IsSearchFolder(folder))
	{
		if (!searchFolder)
			searchFolder = [[SearchFolder alloc] initWithDatabase:db];
		[searchFolder loadCriteria:mainWindow folderId:[node nodeId]];
	}
}

/* handleFolderUpdate
 * Called if a folder content has changed.
 */
-(void)handleFolderUpdate:(NSNotification *)nc
{
	NSInteger folderId = [(NSNumber *)[nc object] integerValue];
	if (folderId == currentFolderId)
	{
		[self setMainWindowTitle:folderId];
		[self refreshFolder:YES];
	}
}

/* handleFolderSelection
 * Called when the selection changes in the folder pane.
 */
-(void)handleFolderSelection:(NSNotification *)note
{
	TreeNode * node = (TreeNode *)[note object];
	NSInteger newFolderId = [node nodeId];

	// We only care if the selection really changed
	if (currentFolderId != newFolderId && newFolderId != 0)
	{
		if (![foldersTree isFolderExpanded:node])
		{
			Folder * newFolder = [db folderFromID:newFolderId];
			while (newFolder && [newFolder permissions] == MA_Empty_Folder)
			{
				newFolderId = [foldersTree firstChildFolder:newFolderId];
				if (newFolderId == [node nodeId])
					break;
				newFolder = [db folderFromID:newFolderId];
			}
		}

		// Blank out the search field
		[(NSSearchField *)searchView setStringValue:@""];

		// Hint: after we call selectFolder, the handleFolderSelection notification
		// will be fired again.
		if (newFolderId != [node nodeId])
			[foldersTree selectFolder:newFolderId];
		else
		{
			if (reinstateThreading)
			{
				reinstateThreading = NO;
				showThreading = YES;
			}
			[self selectFolderWithFilter:newFolderId searchFilter:@""];
			[[NSUserDefaults standardUserDefaults] setInteger:currentFolderId forKey:MAPref_CachedFolderID];
		}
	}
}

/* handleUsernameChange
 * The user name has changed. We need to refresh the current folder
 * so that priority messages are properly updated.
 */
-(void)handleUsernameChange:(NSNotification *)note
{
	[db setUsername:[[NSUserDefaults standardUserDefaults] stringForKey:MAPref_Username]];
	[self refreshFolder:NO];
}

/* handleQuoteColourChange
 * Called when the user changes the quote colour in the Preferences
 */
-(void)handleQuoteColourChange:(NSNotification *)note
{
	NSData * colourData;
	NSColor * newQuoteColour;

	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_QuoteColour];
	newQuoteColour = [[NSUnarchiver unarchiveObjectWithData:colourData] retain];
	[quoteColour release];
	quoteColour = newQuoteColour;
	if (currentSelectedRow != -1)
		[self updateMessageText];
}

/* handlePriorityColourChange
 * Called when the user changes the priority colour in the Preferences
 */
-(void)handlePriorityColourChange:(NSNotification *)note
{
	NSData * colourData;
	NSColor * newPriorityColour;
	
	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_PriorityColour];
	newPriorityColour = [[NSUnarchiver unarchiveObjectWithData:colourData] retain];
	[priorityColour release];
	priorityColour = newPriorityColour;
	[self refreshFolder:NO];
}

/* handleIgnoredColourChange
 * Called when the user changes the ignored colour in the Preferences
 */
-(void)handleIgnoredColourChange:(NSNotification *)note
{
	NSData * colourData;
	NSColor * newIgnoredColour;
	
	colourData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_IgnoredColour];
	newIgnoredColour = [[NSUnarchiver unarchiveObjectWithData:colourData] retain];
	[ignoredColour release];
	ignoredColour = newIgnoredColour;
	[self refreshFolder:NO];
}

/* handleMessageListFontChange
 * Called when the user changes the message list font and/or size in the Preferences
 */
-(void)handleMessageListFontChange:(NSNotification *)note
{
	[self setTableViewFont];
	[messageList reloadData];
}

/* handleMessageFontChange
 * Called when the user changes the message or plain text font and/or size in the Preferences
 */
-(void)handleMessageFontChange:(NSNotification *)note
{
	if (currentSelectedRow != -1)
	{
		[self updateHTMLDict];
		[self updateMessageText];
	}
}

/* handleCheckFrequencyChange
 * Called when the frequency by which we check messages is changed.
 */
-(void)handleCheckFrequencyChange:(NSNotification *)note
{
	NSInteger newFrequency = [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_CheckFrequency];

	[checkTimer invalidate];
	[checkTimer release];
	if (newFrequency > 0)
	{
		checkTimer = [[NSTimer scheduledTimerWithTimeInterval:newFrequency
													   target:self
													 selector:@selector(getMessagesOnTimer:)
													 userInfo:nil
													  repeats:YES] retain];
	}
}

/* setSortColumnIdentifier
 */
-(void)setSortColumnIdentifier:(NSString *)str
{
	[str retain];
	[sortColumnIdentifier release];
	sortColumnIdentifier = str;
}

/* sortMessages
 * Re-orders the messages in currentArrayOfMessages by the current sort order
 */
-(void)sortMessages
{
	NSArray * sortedArrayOfMessages;

	sortedArrayOfMessages = [currentArrayOfMessages sortedArrayUsingFunction:messageSortHandler context:self];
	NSAssert([sortedArrayOfMessages count] == [currentArrayOfMessages count], @"Lost messages from currentArrayOfMessages during sort");
	[currentArrayOfMessages release];
	currentArrayOfMessages = [[NSArray arrayWithArray:sortedArrayOfMessages] retain];
	sortedFlag = NO;
}

/* messageSortHandler
 */
NSInteger messageSortHandler(id i1, id i2, void * context)
{
	AppController * app = (AppController *)context;
	VMessage * item1 = i1;
	VMessage * item2 = i2;

	switch (app->sortColumnTag)
	{
		case MA_ID_MessageId: {
			NSInteger number1 = [item1 messageId];
			NSInteger number2 = [item2 messageId];
			if (number1 < number2)
				return NSOrderedAscending * app->sortDirection;
			if (number2 < number1)
				return NSOrderedDescending * app->sortDirection;
			return NSOrderedSame;
		}

		case MA_ID_MessageComment: {
			NSInteger number1 = [item1 comment];
			NSInteger number2 = [item2 comment];
			if (number1 < number2)
				return NSOrderedAscending * app->sortDirection;
			if (number2 < number1)
				return NSOrderedDescending * app->sortDirection;
			return NSOrderedSame;
		}

		case MA_ID_MessageFolderId: {
			NSInteger number1 = [item1 folderId];
			NSInteger number2 = [item2 folderId];
			if (number1 < number2)
				return NSOrderedAscending * app->sortDirection;
			if (number2 < number1)
				return NSOrderedDescending * app->sortDirection;
			return NSOrderedSame;
		}
			
		case MA_ID_MessageUnread: {
			BOOL n1 = [item1 isRead];
			BOOL n2 = [item2 isRead];
			return (n1 < n2) * app->sortDirection;
		}

		case MA_ID_MessageFlagged: {
			BOOL n1 = [item1 isFlagged];
			BOOL n2 = [item2 isFlagged];
			return (n1 < n2) * app->sortDirection;
		}

		case MA_ID_MessageDate: {
			NSDate * n1 = [[item1 messageData] objectForKey:MA_Column_MessageDate];
			NSDate * n2 = [[item2 messageData] objectForKey:MA_Column_MessageDate];
			return [n1 compare:n2] * app->sortDirection;
		}
			
		case MA_ID_MessageFrom: {
			NSString * n1 = [[item1 messageData] objectForKey:MA_Column_MessageFrom];
			NSString * n2 = [[item2 messageData] objectForKey:MA_Column_MessageFrom];
			return [n1 caseInsensitiveCompare:n2] * app->sortDirection;
		}
			
		case MA_ID_MessageTitle: {
			NSString * n1 = [[item1 messageData] objectForKey:MA_Column_MessageTitle];
			NSString * n2 = [[item2 messageData] objectForKey:MA_Column_MessageTitle];
			return [n1 caseInsensitiveCompare:n2] * app->sortDirection;
		}
	}
	return NSOrderedSame;
}

/* threadMessages
 * Re-orders the messages in currentArrayOfMessages by thread.
 *
 * Note: we have to handle the case where messages are from different folders. We try
 *       to thread those that belong together in the same folder even if there are
 *	     multiple messages with the same number. Be sure not to break this.
 */
-(void)threadMessages
{
	NSMutableArray * threadedArrayOfMessages;
	NSUInteger index = 0;
	NSUInteger count = [currentArrayOfMessages count];

	// If the message array is unsorted, we need to do our own sort before
	// threading. For performance reasons, the threading code assumes that
	// messages are sorted first.
	if (!sortedFlag)
	{
		sortDirection = 1;
		sortColumnTag = MA_ID_MessageId;
		[self sortMessages];
		sortedFlag = YES;
	}
	threadedArrayOfMessages = [[NSMutableArray alloc] initWithArray:currentArrayOfMessages];
	while (index < count)
	{
		VMessage * message = [threadedArrayOfMessages objectAtIndex:index];
		[message setLevel:0];
		[message setLastChildMessage:message];
		if ([message comment] > 0)
		{
			NSInteger parentIndex = index - 1;
			while (parentIndex >= 0)
			{
				VMessage * parentMessage = [threadedArrayOfMessages objectAtIndex:parentIndex];
				if ([parentMessage messageId] == [message comment] && [parentMessage folderId] == [message folderId])
				{
					VMessage * lastChild = [parentMessage lastChildMessage];

					while (lastChild != [lastChild lastChildMessage])
						lastChild = [lastChild lastChildMessage];
					NSUInteger insertIndex = [threadedArrayOfMessages indexOfObject:lastChild] + 1;
					NSAssert(insertIndex <= index, @"Oops!");
					if (insertIndex > 0 && insertIndex != index)
					{
						[threadedArrayOfMessages removeObjectAtIndex:index];
						[threadedArrayOfMessages insertObject:message atIndex:insertIndex];
					}
					[parentMessage setLastChildMessage:message];
					[message setLevel:[parentMessage level] + 1];
					break;
				}
				--parentIndex;
			}
		}
		++index;
	}
	NSAssert(count == [currentArrayOfMessages count], @"Lost messages from currentArrayOfMessages during rethread");
	[currentArrayOfMessages release];
	currentArrayOfMessages = threadedArrayOfMessages;
}

/* makeRowSelectedAndVisible
 * Selects the specified row in the table and makes it visible by
 * scrolling it to the center of the table.
 */
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex
{
	if (rowIndex < 0)
		[infoBarView update:nil database:db];
	else if (rowIndex == currentSelectedRow)
		[self refreshMessageAtRow:rowIndex];
	else
	{   // DJE changed here to use NSIndexSet
		[messageList selectRowIndexes:[ NSIndexSet indexSetWithIndex: rowIndex] byExtendingSelection:NO];
		[self centerSelectedRow];
	}
}

/* centerSelectedRow
 * Center the selected row in the table view.
 */
-(void)centerSelectedRow
{
	NSInteger rowIndex = [messageList selectedRow];
	NSInteger pageSize = [messageList rowsInRect:[messageList visibleRect]].length;
	NSInteger lastRow = [messageList numberOfRows] - 1;
	NSInteger visibleRow = rowIndex + (pageSize / 2);
	
	if (visibleRow > lastRow)
		visibleRow = lastRow;
	[messageList scrollRowToVisible:rowIndex];
	[messageList scrollRowToVisible:visibleRow];
}

/* didClickTableColumns
 * Handle the user click in the column header to sort by that column.
 */
-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSString * columnName = [tableColumn identifier];
	[self sortByIdentifier:columnName];
}

/* tableViewColumnDidResize
 * This notification is called when the user completes resizing a column. We obtain the
 * new column size and save the settings.
 */
-(void)tableViewColumnDidResize:(NSNotification *)notification
{
	NSTableColumn * tableColumn = [[notification userInfo] objectForKey:@"NSTableColumn"];
	VField * field = [db fieldByIdentifier:[tableColumn identifier]];
	NSInteger oldWidth = [[[notification userInfo] objectForKey:@"NSOldWidth"] integerValue];

	if (oldWidth != [tableColumn width])
	{
		[field setWidth:[tableColumn width]];
		[self saveTableSettings];
	}
}

/* doViewColumn
 * Toggle whether or not a specified column is visible.
 */
-(void)doViewColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	VField * field = [menuItem representedObject];

	[field setVisible:![field visible]];
	[self updateVisibleColumns];
	[self saveTableSettings];
}

/* doSortColumn
 * Handle the user picking an item from the Sort By submenu
 */
-(void)doSortColumn:(id)sender
{
	NSMenuItem * menuItem = (NSMenuItem *)sender;
	VField * field = [menuItem representedObject];

	NSAssert1(field, @"Somehow got a nil representedObject for Sort sub-menu item '%@'", [menuItem title]);
	[self sortByIdentifier:[field name]];
}

/* sortByIdentifier
 * Sort by the column indicated by the specified column name.
 */
-(void)sortByIdentifier:(NSString *)columnName
{
	if ([sortColumnIdentifier isEqualToString:columnName])
		sortDirection *= -1;
	else
	{
		[messageList setIndicatorImage:nil inTableColumn:[messageList tableColumnWithIdentifier:sortColumnIdentifier]];
		[self setSortColumnIdentifier:columnName];
		sortDirection = 1;
		sortColumnTag = [self tagFromIdentifier:sortColumnIdentifier];
		[[NSUserDefaults standardUserDefaults] setObject:sortColumnIdentifier forKey:MAPref_SortColumn];
	}
	[[NSUserDefaults standardUserDefaults] setInteger:sortDirection forKey:MAPref_SortDirection];

	// Turn off threading when sorting
	if (showThreading)
	{
		showThreading = NO;
		[[NSUserDefaults standardUserDefaults] setBool:showThreading forKey:MAPref_ShowThreading];
	}
	
	[self showSortDirection];
	[self refreshFolder:NO];
}

/* tagFromIdentifier
 * Given a field identifier, returns the tag associated with that field.
 */
-(NSInteger)tagFromIdentifier:(NSString *)identifier
{
	VField * field = [db fieldByIdentifier:identifier];
	return [field tag];
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display which
 * is equivalent to the number of messages in the current folder.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [currentArrayOfMessages count];
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    VMessage * theRecord;

    NSParameterAssert(rowIndex >= 0 && rowIndex < (NSInteger)[currentArrayOfMessages count]);
    theRecord = [currentArrayOfMessages objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:MA_Column_MessageFolderId])
	{
		return [db folderPathName:[theRecord folderId]];
	}
	if ([[aTableColumn identifier] isEqualToString:MA_Column_MessageId])
	{
		if ([theRecord comment] && [theRecord level] == 0 && currentFolderId != MA_Outbox_NodeID && currentFolderId != MA_Draft_NodeID && showThreading)
#warning 64BIT: Check formatting arguments
			return [NSString stringWithFormat:@"...%d", [theRecord messageId]];
	}
    return [[theRecord messageData] objectForKey:[aTableColumn identifier]];
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	currentSelectedRow = [messageList selectedRow];
	[self refreshMessageAtRow:currentSelectedRow];
}

/* refreshMessageAtRow
 * Refreshes the message at the specified row.
 */
-(void)refreshMessageAtRow:(NSInteger)theRow
{
//	NSLog(@"RefreshmessageAtRow called for row %d",theRow);
	requestedMessage = 0;
	if (theRow < 0)
		[textView setString:@""];
	else
	{
		NSAssert(theRow < (NSInteger)[currentArrayOfMessages count], @"Out of range row index received");
		[self updateMessageText];

		// Make sure we start at the top
		[textView scrollRangeToVisible:NSMakeRange(0, 1)];
		[textView setNeedsDisplayInRect: NSMakeRect(1,0,0,0) avoidAdditionalLayout: NO /* dje here was YES*/];

		// Add this to the backtrack list
		if (!isBacktracking)
		{
			NSInteger messageId = [[currentArrayOfMessages objectAtIndex:theRow] messageId];
			[backtrackArray addToQueue:currentFolderId messageNumber:messageId];
		}
		
		// If profile window is visible, update the contents of the window
		if ([[profileWindow window] isVisible])
		{
			VMessage *message = [currentArrayOfMessages objectAtIndex:theRow];
			NSString * personName = [message sender];
			VPerson * person = [personManager personFromPerson:personName];
			[profileWindow setCurrentPerson:person];
			// static analyser complains
			// [person release];
		}
	}
}

/* handlePersonUpdate
 * Information for a person has changed. If the profile window is visible and showing
 * the profile information for this person then update it.
 */
-(void)handlePersonUpdate:(NSNotification *)note
{
	VPerson * person = (VPerson *)[note object];
	if ([[profileWindow window] isVisible] && [[[profileWindow currentPerson] shortName] isEqualToString:[person shortName]])
	{
		person = [personManager personFromPerson:[person shortName]];
		[profileWindow setCurrentPerson:person];
		// static analyser complains 
		// [person release];
	}
}

/* forwardTrackMessage
 * Forward track through the list of messages displayed
 */
-(IBAction)forwardTrackMessage:(id)sender
{
	NSInteger folderId;
	NSInteger messageNumber;

	if ([backtrackArray nextItemAtQueue:&folderId messageNumber:&messageNumber])
	{
		isBacktracking = YES;
		[self selectFolderAndMessage:folderId messageNumber:messageNumber];
		isBacktracking = NO;
	}
}

/* backTrackMessage
 * Back track through the list of messages displayed
 */
-(IBAction)backTrackMessage:(id)sender
{
	NSInteger folderId;
	NSInteger messageNumber;
	
	if ([backtrackArray previousItemAtQueue:&folderId messageNumber:&messageNumber])
	{
		isBacktracking = YES;
		[self selectFolderAndMessage:folderId messageNumber:messageNumber];
		isBacktracking = NO;
	}
}

/* selectNextRootMessage
 * Move the selection to the next root message
 */
-(void)selectNextRootMessage
{
	NSInteger selectedRow = [messageList selectedRow];
	if (selectedRow == -1)
		return;
	while (++selectedRow < (NSInteger)[currentArrayOfMessages count])
	{
		VMessage * theMessage = [currentArrayOfMessages objectAtIndex:selectedRow];
		if ([theMessage level] == 0)
		{
			[self makeRowSelectedAndVisible:selectedRow];
			break;
		}
	}
}

/* selectPreviousRootMessage
 * Move the selection to the previous root message
 */
-(void)selectPreviousRootMessage
{
	NSInteger selectedRow = [messageList selectedRow];
	if (selectedRow == -1)
		return;
	while (--selectedRow >= 0)
	{
		VMessage * theMessage = [currentArrayOfMessages objectAtIndex:selectedRow];
		if ([theMessage level] == 0)
		{
			[self makeRowSelectedAndVisible:selectedRow];
			break;
		}
	}
}


/*
 * Return the index of the root of the current message
 */
-(NSInteger)findRootMessage
{
	NSInteger selectedRow = [messageList selectedRow];
	if (selectedRow == -1)
		return -1;
	while (++selectedRow < (NSInteger)[currentArrayOfMessages count])
	{
		VMessage * theMessage = [currentArrayOfMessages objectAtIndex:selectedRow];
		if ([theMessage level] == 0)
		{
			return selectedRow;
		}
	}
	return -1;
}

-(void)viewNextUnreadRoot
{
	VMessage * theMessage = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
	NSInteger oldFolder = [theMessage folderId];
	NSInteger oldSelectedRow = [self findRootMessage];
				
	[self viewNextUnread: self];
	NSInteger newSelectedRow = [self findRootMessage];
				
	theMessage = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
	NSInteger newFolder = [theMessage folderId];

	if ( (oldFolder != newFolder || oldSelectedRow != newSelectedRow) && [theMessage level] != 0) 
	{
		[self selectPreviousRootMessage];
	}	
}


/* handleKeyDown [delegate]
 * Support special key codes. If we handle the key, return YES otherwise
 * return NO to allow the framework to pass it on for default processing.
 */
-(BOOL)handleKeyDown:(unichar)keyChar withFlags:(NSUInteger)flags
{
	switch (keyChar)
	{
		case 0x7F:
			[self backTrackMessage:self];
			return YES;

		case NSRightArrowFunctionKey:
			[self selectNextRootMessage];
			return YES;

		case NSLeftArrowFunctionKey:
			[self selectPreviousRootMessage];
			return YES;

		case 'c':
		case 'C':
			[self replyToMessage:self];
			return YES;

		case 'f':
		case 'F':
			[mainWindow makeFirstResponder:searchView];
			return YES;

		case 'g':
		case 'G':
			[self gotoMessage:self];
			return YES;

		case 'h':
		case 'H':
			[self viewNextPriorityUnread:self];
			return YES;

		case 'i':
		case 'I':
			if (flags & NSShiftKeyMask)
				[self markThreadFromRootIgnored:self];
			else
				[self markIgnored:self];
			return YES;
			
		case 'm':
		case 'M':
			if (flags & NSShiftKeyMask)
				[self markThreadFromRootFlagged:self];
			else
				[self markFlagged:self];
			return YES;
			
		case 'o':
		case 'O':
			[self originalMessage:self];
			return YES;
			
		case 'p':
		case 'P':
			if (flags & NSShiftKeyMask)
				[self markThreadFromRootPriority:self];
			else
				[self markPriority:self];
			return YES;

		case 'r':
		case 'R':
			if (flags & NSShiftKeyMask)
				[self markThreadFromRootRead:self];
			else
				[self markRead:self];
			return YES;

		case 's':
		case 'S':
			[self newMessage:self];
			return YES;

		case 'z':
			[self markThreadRead:self];
			[self viewNextUnread:self];
			return YES;

		case 'Z':
			[self markThreadRead:self];
			[self viewNextUnreadRoot];
			return YES;

		case '\r': //ENTER
			[self viewNextUnread:self];
			return YES;

		case '/': //Move to the root message of the next unread message.
			[self viewNextUnreadRoot];
			return YES;
			
		case ' ': //SPACE
			{
			NSRect preVisible;
			NSRect postVisible;

			// The way we work out if we need to move to the next
			// message is to take note of the text visible rect
			// coordinates, page down, then check the coordinates
			// again to see if anything changed.
			//
			// steve: OK, so this is broken. I went back to 1.0.2 and
			// this still doesn't work. I'm sure it worked at some
			// point though.
			//
			preVisible = [textView visibleRect];
		//		LogRect(@"Previsible", preVisible);
			[textView pageDown:self];
			postVisible = [textView visibleRect];
		//		LogRect(@"PostVisible", postVisible);
#if 0
// DJE
// The next 2 lines have been #if'ed out
// to fix the scrolling bug where the message view scrolls down too far.
			if (NSEqualRects(preVisible, postVisible))
				[self viewNextUnread:self];
#endif
			return YES;
			}
	}
	return NO;
}

/* doubleClickRow
 * Handles the double-click action in a non-empty row.
 */
-(void)doubleClickRow:(id)sender
{
	NSInteger selectedRow = [messageList selectedRow];
	if (selectedRow >= 0 && selectedRow < (NSInteger)[currentArrayOfMessages count])
	{
		Folder * folder = [db folderFromID:currentFolderId];
		VMessage * message = [currentArrayOfMessages objectAtIndex:selectedRow];

		if ([folder permissions] == MA_ReadWrite_Folder)
		{
			MessageWindow * msgWindow;

			msgWindow = [self messageWindowWithAttributes:currentFolderId messageNumber:[message messageId]];
			if (msgWindow == nil)
				msgWindow = [[MessageWindow alloc] initMessageFromMessage:db message:message];
			[[msgWindow window] makeKeyAndOrderFront:self];
		}
	}
}

/* canPostMessage [delegate]
 * Called by the connection code to ask if we can post the specified
 * message. We deny only if the specified message is being edited.
 */
-(BOOL)canPostMessage:(NSInteger)folderId messageNumber:(NSInteger)messageNumber
{
	return [self messageWindowWithAttributes:folderId messageNumber:messageNumber] == nil;
}

/* messageWindowWithAttributes
 * Locates an existing open message window with the specified parent folder ID and message
 * number, and returns the MessageWindow object found.
 */
-(MessageWindow *)messageWindowWithAttributes:(NSInteger)folderId messageNumber:(NSInteger)messageNumber
{
	NSArray * windowArray = [NSApp windows];
	NSEnumerator * enumerator = [windowArray objectEnumerator];
	NSWindow * theWindow;

	while ((theWindow = [enumerator nextObject]) != nil)
	{
		MessageWindow * messageWindow = [theWindow windowController];
		if ([messageWindow isKindOfClass:[MessageWindow class]] && [[messageWindow window] isVisible])
		{
			VMessage * message = [messageWindow message];
			if ([message folderId] == folderId && [message messageId] == messageNumber)
				return messageWindow;
		}
	}
	return nil;
}

/* closeAllMessageWindows
 * Loop for all open message windows and give them a chance to save themselves
 * if they were modified.
 */
-(BOOL)closeAllMessageWindows
{
	NSArray * windowArray = [NSApp windows];
	NSEnumerator * enumerator = [windowArray objectEnumerator];
	NSWindow * theWindow;
	
	while ((theWindow = [enumerator nextObject]) != nil)
	{
		MessageWindow * messageWindow = [theWindow windowController];
		if ([messageWindow isKindOfClass:[MessageWindow class]])
		{
			if (![messageWindow windowShouldClose:nil])
				return NO;
		}
	}
	return YES;
}

/* willDisplayCell [delegate]
 * Catch the table view before it displays a cell.
 */
-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	VMessage * message = [currentArrayOfMessages objectAtIndex:rowIndex];

	// Show priority messages in the priority message colour.
	if (![aCell isKindOfClass:[NSImageCell class]])
	{
		if ([message isIgnored])
			[aCell setTextColor:ignoredColour];
		else if ([message isPriority])
			[aCell setTextColor:priorityColour];
		else
			[aCell setTextColor:[NSColor blackColor]];
	
		if ([message level] == 0 && showThreading)
			[aCell setFont:boldMessageListFont];
		else
			[aCell setFont:messageListFont];
	}
	if (!showThreading)
	{
		if ([[aTableColumn identifier] isEqualToString:MA_Column_MessageId])
		{
			[aCell setImage:nil];
			[aCell setOffset:0];
		}
	}
	else
	{
		if ([[aTableColumn identifier] isEqualToString:MA_Column_MessageId])
		{
			if ([message lastChildMessage] != message)
				[aCell setImage:[NSImage imageNamed:@"greyRightArrow.tiff"]];
			else
				[aCell setImage:[NSImage imageNamed:@"blankSquare.tiff"]];
			[aCell setOffset:[message level]];
		}
	}
}

/* handleMugshotFolderChanged
 * Called when the user changes the mugshot folder in Preferences. We take this
 * opportunity to recache our copy of the folder name.
 */
-(void)handleMugshotFolderChanged:(NSNotification *)nc
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSInteger height;

	NSString *tmp = [nc object];
	if (tmp)
	{
		height = [defaults integerForKey:MAPref_MugshotsSize];

		// if only the gears are visible, open it up a bit
		if (height == MUGSHOTS_DISABLED_SIZE)
			height = MUGSHOTS_DEFAULT_SIZE;
		showMugshots = YES;
	}
	else
	{
		height = MUGSHOTS_DISABLED_SIZE;
		[mugshotView setImage:nil];
		showMugshots = NO;
	}
	[self resizeMugshotView:height];
	[defaults setObject:[NSNumber numberWithLong:(long)height] forKey:MAPref_MugshotsSize];
	[personManager setMugshotFolder:tmp];

	// if the window has been newly open (or the folder changed) then refresh the mugshot display
	if (tmp)
		[self updateMessageText];
}

/* updateMessageText
 * Updates the message text for the current selected message possibly because
 * some of the message attributes have changed.
 */
-(void)updateMessageText
{
	VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
	NSString * messageText = [db messageText:[theRecord folderId] messageId:[theRecord messageId]];

	NSAttributedString * attrText = [self formatMessage:messageText usePlainText:showPlainText];
	[[textView textStorage] setAttributedString:attrText];
	// static analyser complains
	// [attrText release];
	
	[infoBarView update:theRecord database:db];
	[self displayMugshot:theRecord];
}

/* displayMugshot
 * Display the mugshot for the specified message.
 */
-(void)displayMugshot:(VMessage *)theRecord
{
	if (showMugshots)
	{
		VPerson * person;
		Folder * folder =[db folderFromID:[foldersTree actualSelection]];
		Folder * parent = [db folderFromID:[folder parentId]];

		// Look for a conference mugshot first
		NSString *confPerson = [NSString stringWithFormat:@"%@-%@", [parent name], [theRecord sender]];
		person = [personManager personFromPerson:confPerson];
	
		// Consult the PersonManager for the poster's mugshot
		if (!person || ![person picture])
			person = [personManager personFromPerson:[theRecord sender]];

		if (person && [person picture])
		{
			// This bit of magic overrides the DPI settings often found in JPEG
			// files. without it, if a JPEG has (eg) a DPI of 300 then it will display
			// about a quarter of it's bitmap size (display is 72dpi).
			NSImageRep * rep = [[person picture] bestRepresentationForDevice: nil];	
			NSSize size;
			size.width = [rep pixelsWide];
			size.height = [rep pixelsHigh];
			[[person picture] setSize: size];
			[mugshotView setImage:[person picture]];
		}
		else
		{
			[mugshotView setImage:nil];
		}
		// static analyser complains
		// [person release];
	}
}

/* resizeMugshotView
 * Resize the mugshot view window.
 */
-(void)resizeMugshotView:(NSInteger)height
{
	NSSplitView *splitter = (NSSplitView *)[[[mugshotView superview] superview] superview];
	NSRect       foldersFrame, mugshotFrame;
    NSView      *foldersSubview;
    NSView      *mugshotSubview;
	CGFloat        totalHeight;
    	
    // Get the bits
    foldersSubview = [[splitter subviews] objectAtIndex:0];
    mugshotSubview = [[splitter subviews] objectAtIndex:1];
    foldersFrame = [foldersSubview frame];
    mugshotFrame = [mugshotSubview frame];
	
	// Work out the new sizes
	totalHeight = mugshotFrame.size.height + foldersFrame.size.height;
	mugshotFrame.size.height = height;
	foldersFrame.size.height = totalHeight - mugshotFrame.size.height;
	
	// Set the new sizes & redisplay
    [foldersSubview setFrame:foldersFrame];
    [mugshotSubview setFrame:mugshotFrame];
    [splitter adjustSubviews];
    [splitter setNeedsDisplay: YES];
}

/* formatMessage
 * Format the message by making URLs into clickable links, bold, italic and underline specifiers into
 * their actual attributes and formatting quotes.
 */
-(NSAttributedString *)formatMessage:(NSString *)messageText usePlainText:(BOOL)usePlainText
{
	NSMutableAttributedString * attrMessageText = nil;
	const char * charptr = nil;
	NSInteger rangeIndex;
	NSInteger attrRangeIndex;
	NSInteger quoteRangeStart;
	NSInteger urlRangeStart;
	NSInteger wordRangeStart;
	NSInteger whitespacesToSkip;
	BOOL isAtStartOfLine;
	BOOL plainText;
	BOOL isInWordBreak;
	BOOL isGrouping;
	BOOL doStyleURL;
	BOOL isCopiedFromGroup;
	NSInteger  enc;
	NSRange wordRange;
	NSString *mactext = nil;
	
	// Initialise local vars
	rangeIndex = 0;
	attrRangeIndex = 0;
	quoteRangeStart = -1;
	urlRangeStart = -1;
	wordRangeStart = -1;
	wordRange.length = 0;
	whitespacesToSkip = 0;
	isAtStartOfLine = YES;
	isInWordBreak = YES;
	isGrouping = NO;
	doStyleURL = NO;
	plainText = showPlainText;
	isCopiedFromGroup = NO;
	
	// Create our fonts up-front
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:(usePlainText ? MAPref_PlainTextFont : MAPref_MessageFont)];
	NSFont * messageFont = [NSUnarchiver unarchiveObjectWithData:fontData];
	
	// Styled dictionaries
	NSMutableDictionary * boldAttr = [NSMutableDictionary dictionary];
	[boldAttr setValue:[[NSFontManager sharedFontManager] convertWeight:YES ofFont:messageFont] forKey:NSFontAttributeName];
	
	NSMutableDictionary * italicAttr = [NSMutableDictionary dictionary];
	[italicAttr setValue:[[NSFontManager sharedFontManager] convertFont:messageFont toHaveTrait:NSItalicFontMask] forKey:NSFontAttributeName];
	
	NSMutableDictionary * underlineAttr = [NSMutableDictionary dictionary];
	[underlineAttr setValue:messageFont forKey:NSFontAttributeName];
	[underlineAttr setValue:[NSNumber numberWithLong:(long)NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
	
	// If message text begins with <html> then we render as HTML only
	// Deprecated API was here DJE
	// The messageText should have already been sanitised, otherwise expect a crash (DJE)
	NSData * chardata = [[NSData alloc] 
						 initWithBytes:[messageText
										cStringUsingEncoding:NSWindowsCP1252StringEncoding]
						 length:[messageText length]];
	if ([messageText hasPrefix:@"<HTML>"])
	{
		attrMessageText = [[NSMutableAttributedString alloc] initWithHTML:chardata options:htmlDict documentAttributes:nil];
		[chardata autorelease];
		plainText = YES;
	}
	else
	{
		if (showWindowsCP)
			enc = NSWindowsCP1252StringEncoding;
		else
			enc = NSISOLatin1StringEncoding;
		
		// Convert using selected charset.
		@try 
		{
			mactext = [[NSString alloc] initWithData: chardata encoding: enc];
			// deprecated API was here DJE
		//	charptr = [mactext cString];
			// replacement here
			charptr = [mactext cStringUsingEncoding:NSWindowsCP1252StringEncoding];

			attrMessageText = [[NSMutableAttributedString alloc] initWithString: mactext];
			messageText = mactext;
		}
		@catch (NSException *e)
		{
			// Can't convert the string, display it as-is
			attrMessageText = [[NSMutableAttributedString alloc] initWithString:messageText];
			// deprecated API was here DJE
			//charptr = [messageText cString];
			// replacement here
			charptr = [messageText cStringUsingEncoding:NSWindowsCP1252StringEncoding];

		}
		[chardata autorelease];
		[mactext autorelease];

		// Set the font for the entire message
		NSRange entireTextRange = NSMakeRange(0, [attrMessageText length]);
		[attrMessageText addAttribute:NSFontAttributeName value:messageFont range:entireTextRange];
	}

	if (!plainText)
	{
		while (*charptr)
		{		
			if (*charptr == '>' && isAtStartOfLine)
				quoteRangeStart = attrRangeIndex;
			
			if (*charptr != ' ' && *charptr != '\t')
				isAtStartOfLine = NO;

			if (acronymDictionary && !isalnum(*charptr) && rangeIndex > wordRangeStart)
			{
				wordRange = NSMakeRange(wordRangeStart+1, rangeIndex-wordRangeStart-1);
				wordRangeStart = rangeIndex;
			}
			
			// Handle **COPIED FROM links
			if (strncasecmp(charptr, "**COPIED FROM:", 14) == 0)
			{
				urlRangeStart = rangeIndex;
				whitespacesToSkip = 4;
				isCopiedFromGroup = YES;
			}
			
			// Handle styles
			if ((*charptr == '*' || *charptr == '/' || *charptr == '_') && isInWordBreak && urlRangeStart == -1)
			{
				NSInteger styleRangeStart = rangeIndex;
				NSInteger styleRangeTextStart = attrRangeIndex;
				NSInteger styleRangeTextLength = 0;
				NSInteger styleRangeLength = 1;
				const char * charptrStart = charptr + 1;
				char endStyleChar = *charptr;
				
				while (*++charptr && *charptr != endStyleChar && *charptr != '\r' && *charptr != '\n')
				{
					++styleRangeLength;
					++styleRangeTextLength;
				}

				// We can only legally style the sequence if:
				// - we hit a matching end of style character on the same line.
				// - the end of style character is followed by tab, newline, period, comma, closing parenthesis, qmark or exclmark.
				// - the style range is 3 chrs or more.
				//
				if (*charptr != endStyleChar || *charptrStart == ' ' || (*charptr && strchr(" \t\r\n,.)!?", *(charptr+1)) == 0) || styleRangeLength < 2)
				{
					rangeIndex = styleRangeStart + 1;
					attrRangeIndex = styleRangeTextStart + 1;
					charptr = charptrStart;
				}
				else
				{
					++styleRangeLength;
					++charptr;
					NSDictionary * styleAttr = nil;
					switch (endStyleChar)
					{
						case '*': styleAttr = boldAttr; break;
						case '/': styleAttr = italicAttr; break;
						case '_': styleAttr = underlineAttr; break;
					}
					
					NSString * styleString = [messageText substringWithRange:NSMakeRange(styleRangeStart + 1, styleRangeTextLength)];
					NSAttributedString * attrString = [[NSAttributedString alloc] initWithString:styleString attributes:styleAttr];
					
					[attrMessageText replaceCharactersInRange:NSMakeRange(styleRangeTextStart, styleRangeLength) withAttributedString:attrString];
					[attrString release];
					
					rangeIndex += styleRangeLength;
					attrRangeIndex += styleRangeTextLength;
				}
				continue;
			}

			// Look for common URLs that we know about.
			if (*charptr == ':' && urlRangeStart == -1)
			{
				if (rangeIndex >= 4 && strncasecmp(charptr - 4, "http", 4) == 0)
					urlRangeStart = rangeIndex - 4;
				if (rangeIndex >= 5 && strncasecmp(charptr - 5, "https", 5) == 0)
					urlRangeStart = rangeIndex - 5;
				if (rangeIndex >= 3 && strncasecmp(charptr - 3, "cix", 3) == 0)
					urlRangeStart = rangeIndex - 3;
				if (rangeIndex >= 7 && strncasecmp(charptr - 7, "cixfile", 7) == 0)
					urlRangeStart = rangeIndex - 7;
				if (rangeIndex >= 3 && strncasecmp(charptr - 3, "url", 3) == 0)
					urlRangeStart = rangeIndex - 3;
				if (rangeIndex >= 3 && strncasecmp(charptr - 3, "ftp", 3) == 0)
					urlRangeStart = rangeIndex - 3;
				if (rangeIndex >= 6 && strncasecmp(charptr - 6, "mailto", 6) == 0)
					urlRangeStart = rangeIndex - 6;
			}
			
			// Support < and > around a multi-line URL
			if (*charptr == '<' && !isGrouping)
				isGrouping = YES;
			if (*charptr == '>' && isGrouping)
			{
				isGrouping = NO;
				doStyleURL = YES;
			}

			// Handle end of links by styling it NSLinkAttributeName and creating a
			// URL object so the system will do the rest automatically.
			if (*charptr == ' ' || *charptr == '\t' || *charptr == '\r' || *charptr == '\n')
			{
				if (whitespacesToSkip)
					--whitespacesToSkip;
				
				if (urlRangeStart != -1 && !isGrouping && whitespacesToSkip == 0)
				{
					// Skip trailing characters not part of the URL.
					while (attrRangeIndex > 0 && (*(charptr - 1) == '.' || *(charptr - 1) == '>' || *(charptr - 1) == ')'))
					{
						--attrRangeIndex;
						--rangeIndex;
						--charptr;
					}
					doStyleURL = YES;
				}
				isInWordBreak = YES;
			}
			else
				isInWordBreak = NO;

			// Style a URL
			if (doStyleURL)
			{
				NSRange urlRange = NSMakeRange(urlRangeStart, (rangeIndex - urlRangeStart));
				NSMutableString * urlString = [NSMutableString stringWithString:[messageText substringWithRange:urlRange]];
				
				// Drop the initial url: prefix
				if ([[urlString lowercaseString] hasPrefix:@"url:"])
					[urlString deleteCharactersInRange:NSMakeRange(0, 4)];
				
				// Special case COPIED FROM URLs
				if (isCopiedFromGroup)
				{
					NSScanner * scanner = [NSScanner scannerWithString:urlString];
					NSString * folderPart = nil;
					NSString * numberPart = nil;
					
					[scanner scanString:@"**COPIED FROM: >>>" intoString:nil];
					[scanner scanUpToString:@" " intoString:&folderPart];
					[scanner scanString:@" " intoString:nil];
					[scanner scanUpToString:@"" intoString:&numberPart];
					if (folderPart && numberPart)
						urlString = [NSMutableString stringWithFormat:@"cix:%@:%@", folderPart, numberPart];
					else if (folderPart)
						urlString = [NSMutableString stringWithFormat:@"cix:%@", folderPart];
				}
	
				// Strip newlines from the URL
				[urlString replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [urlString length])];
				NSURL * url = [NSURL URLWithString:urlString];
				if (url != nil)
				{
					NSInteger diff = rangeIndex - attrRangeIndex;
					NSRange attrRange = NSMakeRange(urlRangeStart - diff, (rangeIndex - urlRangeStart));
					[attrMessageText addAttribute:NSLinkAttributeName value:url range:attrRange];
				}
				urlRangeStart = -1;
				doStyleURL = NO;
				isCopiedFromGroup = NO;
			}

			// Look for acronyms
			if (!doStyleURL && wordRange.length > 0 && (!isalnum(*charptr)))
			{
				NSString *wordString = [[NSString alloc]initWithBytes: (charptr-wordRange.length) length: wordRange.length encoding: NSISOLatin1StringEncoding];
				NSString *expansion = nil;
				expansion = [acronymDictionary objectForKey:wordString];
				if (expansion && [attrMessageText length] > wordRange.location + wordRange.length)
					[attrMessageText addAttribute:NSToolTipAttributeName value:expansion range:wordRange];
			}

			if (*charptr == '\n' || *charptr == '\r')
			{
				// If this line started with a '>' then we treat it as a quoted line
				// and set the appropriate quote colour.
				if (quoteRangeStart != -1)
				{
					NSRange quoteRange = NSMakeRange(quoteRangeStart, (attrRangeIndex - quoteRangeStart) + 1);
					[attrMessageText addAttribute:NSForegroundColorAttributeName value:quoteColour range:quoteRange];
					quoteRangeStart = -1;
				}
				isAtStartOfLine = YES;
			}
			
			++charptr;
			++rangeIndex;
			++attrRangeIndex;
		}
	}
// DJE deleted the next line. It causes a crash in vmware/general:1915,
// which uses italic messages styles, when running on Leopard SDK without
// garbage collection.  It works perfectly OK on Tiger SDK, for some
// reason I do not know.
//	[messageFont release];   **** deleted, we do not own this object ****
	return attrMessageText;
}

/* isConnecting
 * Returns whether or not 
 */
-(BOOL)isConnecting
{
	return [connect isProcessing];
}

/* getMessagesOnTimer
 * Each time the check timer fires, we see if a connect is not
 * running and then kick one off.
 */
-(void)getMessagesOnTimer:(NSTimer *)aTimer
{
	if ((connect == nil || ![connect isProcessing]) && ![self isBusy])
		[self getMessages:self];
}

/* mugshotUpdated
 * An image was dragged onto the mugshots window, save it.
 */
-(IBAction)mugshotUpdated:(id)sender
{
	VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];

	// Get dropped image and save it.
	NSData * TIFFData = [[mugshotView image] TIFFRepresentationUsingCompression: NSTIFFCompressionLZW factor: 1.0];
	[personManager setPersonImage:[theRecord sender] image:TIFFData];
}

/* newRSSSubscription
 * Display the pane for a new RSS subscription.
 */
-(IBAction)newRSSSubscription:(id)sender
{
	if (!rssFeed)
		rssFeed = [[RSSFeed alloc] initWithDatabase:db];
	[rssFeed newRSSSubscription:mainWindow initialURL:nil];
}

/* editRSSSubscription
 * Display the pane to edit an RSS subscription.
 */
-(IBAction)editRSSSubscription:(id)sender
{
	if (!rssFeed)
		rssFeed = [[RSSFeed alloc] initWithDatabase:db];
	
	NSInteger folderId = [foldersTree actualSelection];
	[rssFeed editRSSSubscription:mainWindow folderId:folderId];
}

-(void)uploadPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		// Get the full path of the folder
		NSInteger folderId = [foldersTree actualSelection];
		NSString * folderPath = [db folderPathName:folderId];

		NSArray * fileNames = [panel filenames];
		NSEnumerator *enumerator = [fileNames objectEnumerator];
		id oneName;
		while ( (oneName = [enumerator nextObject]) ) 
		{
			// Create a task per filename
			[db addTask:MA_TaskCode_FileUpload actionData:(NSString *)oneName folderName:folderPath orderCode:MA_OrderCode_FileUpload];		
		}
		// Save last used folder
		NSString *firstFile = [fileNames objectAtIndex: 0];
		firstFile = [firstFile stringByDeletingLastPathComponent];
		[[NSUserDefaults standardUserDefaults] setObject: firstFile forKey: MAPref_LastUploadFolder];
	}
}

/* uploadFile
*/
-(IBAction)uploadFile:(id)sender
{
	//Use file selector sheet to select file & create TAsk
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSString *initialFolder = [[NSUserDefaults standardUserDefaults] stringForKey: MAPref_LastUploadFolder];
	
	if (initialFolder == nil)
		initialFolder = @"~/Documents";
	
	[panel beginSheetForDirectory: initialFolder
							 file: nil
							types: nil
				   modalForWindow: mainWindow
					modalDelegate: self
				   didEndSelector: @selector(uploadPanelDidEnd: returnCode: contextInfo: )
					  contextInfo: nil];
	
	[panel setCanChooseDirectories: NO];
	[panel setCanChooseFiles: YES];
	[panel setAllowsMultipleSelection: YES];
}

-(IBAction)cancelUpload:(id)sender
{
	[downloadWindow orderOut:sender];
	[NSApp endSheet:downloadWindow returnCode:NSCancelButton];
}

-(IBAction)okUpload:(id)sender
{
	[downloadWindow orderOut:sender];
	[NSApp endSheet:downloadWindow returnCode:NSOKButton];
}

-(void)downloadSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSString * filename = [downloadFilename stringValue];
	
	if (returnCode == NSOKButton)
	{
		// Get the full path of the folder
		NSInteger folderId = [foldersTree actualSelection];
		NSString * folderPath = [db folderPathName:folderId];
		
		// Create a task to do it
		[db addTask:MA_TaskCode_FileDownload actionData:filename folderName:folderPath orderCode:MA_OrderCode_FileDownload];
	}
}

/* downloadFile dialogue
*/
-(IBAction)downloadFile:(id)sender
{
	NSInteger folderId = [foldersTree actualSelection];
	NSString * folderPath = [db folderPathName:folderId];
	
	// TODO ?? Maybe set filename in advance from message ??
	[downloadFilename setStringValue:@""];
	
	// Show which conference/topic
	[downloadConference setStringValue: folderPath];
	
	// Fire up the sheet
	[NSApp beginSheet:downloadWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(downloadSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

/* newSearchFolder
 * Create a new search folder.
 */
-(IBAction)newSearchFolder:(id)sender
{
	if (!searchFolder)
		searchFolder = [[SearchFolder alloc] initWithDatabase:db];
	[searchFolder newCriteria:mainWindow];
}

/* editSearchFolder
 * Edits the current search folder.
 */
-(IBAction)editSearchFolder:(id)sender
{
	if (!searchFolder)
		searchFolder = [[SearchFolder alloc] initWithDatabase:db];

	NSInteger folderId = [foldersTree actualSelection];
	[searchFolder loadCriteria:mainWindow folderId:folderId];
}

-(NSInteger)checkBeta
// Check if we are using the beta server and alert the user (added 2013-10-15)

{
//	NSLog(@"checkbeta");
	
	NSString *infotext  = [NSString stringWithFormat: @"Using the Cix beta server at %s. To disable this and to use the normal server"
						   ", remove the file \"%s\" from"
						   " your home folder and restart Vole.",cixLocation_cstring, volecixbetaname];
	if(cixbetaflag) {  // We are using the cix beta server
		NSAlert * askUserAlert = [NSAlert alertWithMessageText:@"Cix Beta"
												 defaultButton:@"Continue"
											   alternateButton:@"Abort Connect"
												   otherButton:nil
									 informativeTextWithFormat:infotext];
		if ([askUserAlert runModal] != NSAlertDefaultReturn){
			return 1;
		}
	}
	return 0;
}

/* getMessages
 * Get new messages from the service.
 */
-(IBAction)getMessages:(id)sender
{
	if ([connect isProcessing])
		[connect abortConnect];
	else
	{ 
		if( [self checkBeta ] == 1) return;
		if ([self beginConnect: MA_ConnectMode_Both])
		{
			batchConnect = YES;
			[connect processOfflineTasks];
			batchConnect = NO;
		}
	}
}

/* getRSSMessages
 * Get new RSS messages from the service.
 */
-(IBAction)getRSSMessages:(id)sender
{
	if ([connect isProcessing])
		[connect abortConnect];
	else
	{
		if ([self beginConnect: MA_ConnectMode_RSS])
		{
			batchConnect = YES;
			[connect processOfflineTasks];
			batchConnect = NO;
		}
	}
}

/* getCixMessages
 * Get new Cix messages from the service.
 */
-(IBAction)getCixMessages:(id)sender
{
	if ([connect isProcessing])
		[connect abortConnect];
	else
	{
		if ([self checkBeta ] == 1 ) return;
		if ([self beginConnect: MA_ConnectMode_Cix])
		{
			batchConnect = YES;
			[connect processOfflineTasks];
			batchConnect = NO;
		}
	}
}

/* newMessage
 * Create a new message in the current folder.
 */
-(IBAction)newMessage:(id)sender
{
	Folder * folder = [db folderFromID:currentFolderId];
	if (folder && !IsRSSFolder(folder) && ![db readOnly])
	{
		MessageWindow * msgWindow;
		
		msgWindow = [[MessageWindow alloc] initNewMessage:db recipient:[db folderPathName:currentFolderId] commentNumber:(NSInteger)0 initialText: nil];
		[[msgWindow window] makeKeyAndOrderFront:self];
	}
}

/* makeReplyText
 * Build the reply based on the current message and which bits (if any)
 * of it are selected.
 */
-(NSString *)makeReplyText
{
	NSMutableString *quoteString = [[NSMutableString alloc] init];

	// Get the text selected in the message view, if any
	NSRange range = [textView selectedRange];
	if (range.length != 0)
	{
		NSString *messageText;

		messageText = [[textView textStorage] string];
		messageText = [messageText substringWithRange: range];

		[quoteString setString: @"> "];
		[quoteString appendString: messageText];
		[quoteString replaceOccurrencesOfString: @"\n" withString: @"\n> " options:0 range: NSMakeRange(0, [messageText length])];

		[quoteString appendString: @"\n"];
	}
	return quoteString;
}

/* replyToMessage
 * Reply to the selected message.
 */
-(IBAction)replyToMessage:(id)sender
{
	Folder * folder = [db folderFromID:currentFolderId];
	if (folder && !IsRSSFolder(folder) && currentSelectedRow >= 0 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
		NSString * nodePath = [db folderPathName:[theRecord folderId]];
		NSInteger comment = [theRecord messageId];
		MessageWindow * msgWindow;

		// Look for an existing reply in the draft folder.
		// If not there, look for an existing reply in the outbox folder
		// If a reply is found in either place, look for an open window.
		NSMutableDictionary * criteriaDictionary = [[NSMutableDictionary alloc] init];
#warning 64BIT: Check formatting arguments
		NSString * commentString = [NSString stringWithFormat:@"%d", comment];
#warning 64BIT: Check formatting arguments
		NSString * outBoxFolder = [NSString stringWithFormat:@"%d", MA_Outbox_NodeID];
#warning 64BIT: Check formatting arguments
		NSString * draftFolder = [NSString stringWithFormat:@"%d", MA_Draft_NodeID];

		[criteriaDictionary setObject:[NSArray arrayWithObjects:commentString, nil] forKey:MA_Column_MessageComment];
		[criteriaDictionary setObject:[NSArray arrayWithObjects:outBoxFolder, draftFolder, nil] forKey:MA_Column_MessageFolderId];
		[criteriaDictionary setObject:[NSArray arrayWithObjects:nodePath, nil] forKey:MA_Column_MessageFrom];

		// The logic here is as follows:
		// If there's an existing message in either the out basket or draft folder, then look to
		// see if there's an open message window for that message. If so, just switch to it
		// otherwise open the message.
		// If there's no existing message, create one.
		// TODO: this code duplicates logic in [self doubleClickRow]. Merge them.
		// BUG: If there's an existing comment window that has NOT been committed then we open a
		// second comment window.
		//
		NSArray * messageArray = [db findMessages:criteriaDictionary];
		if ([messageArray count] > 0)
		{
			VMessage * message = [messageArray objectAtIndex:0];

			msgWindow = [self messageWindowWithAttributes:[message folderId] messageNumber:[message messageId]];
			if (msgWindow == nil)
				msgWindow = [[MessageWindow alloc] initMessageFromMessage:db message:message];
		}
		else
		{
			NSString *reply = [self makeReplyText];
			msgWindow = [[MessageWindow alloc] initNewMessage:db recipient:nodePath commentNumber:(NSInteger)comment initialText:reply];
			// static analyser complains
			// [reply release];
		}
		[[msgWindow window] makeKeyAndOrderFront:self];
		// static analyser complains
		// [messageArray release];

		// Clean up on the way out.
		[criteriaDictionary release];
	}
}

/* replyByMail
 * Sends a reply using whatever e-mail software is configured on the user's
 * system.
 */
-(IBAction)replyByMail:(id)sender
{
	if (currentSelectedRow >= 0)
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
		NSMutableString * title;

		if ([[NSMutableString class] instancesRespondToSelector:@selector(stringByAddingPercentEscapesUsingEncoding:)])
			title = [[NSMutableString alloc]  // DJE modified fix to cure assigning NSMUtable string from NSString warning
                        initWithString:[[theRecord title] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding] ];
		else
		{
			title = [[NSMutableString alloc] initWithString:[theRecord title]];
			[title replaceOccurrencesOfString:@" " withString:@"%20" options:NSLiteralSearch range:NSMakeRange(0, [title length])];
		}
		
		// See if the user has a preferred e-mail address.
		NSString * emailAddress;
		VPerson * person = [personManager personFromPerson:[theRecord sender]];
		if (person != nil)
			emailAddress = [person emailAddress];
		else
			emailAddress = [NSString stringWithFormat:@"%@@cix.co.uk", [theRecord sender]];

		NSURL * mailURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"mailto:%@?subject=Re:%@", emailAddress, title]];
		[[NSWorkspace sharedWorkspace] openURL:mailURL];

		// Clean up at the end
		[mailURL release];
		// static analyser complains
		// [person release];
		[title release];
	}
}

/* deleteMessage
 * Delete the current message
 */
-(IBAction)deleteMessage:(id)sender
{
	if (currentSelectedRow >= 0)
#warning 64BIT: Check formatting arguments
		NSBeginCriticalAlertSheet (NSLocalizedString(@"Delete selected message", nil),
								  NSLocalizedString(@"Delete", nil),
								  NSLocalizedString(@"Cancel", nil),
								  nil, [NSApp mainWindow], self,
								  @selector(doConfirmedDelete:returnCode:contextInfo:), nil, nil,
								  NSLocalizedString(@"Delete selected message text", nil));
}

/* doConfirmedDelete
 * This function is called after the user has dismissed
 * the confirmation sheet.
 */
-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
	{		
		// Make a new copy of the currentArrayOfMessages with the selected message removed.
		NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfMessages];
		BOOL needFolderRedraw = (currentFolderId == MA_Outbox_NodeID || currentFolderId == MA_Draft_NodeID);

		// Iterate over every selected message in the table and remove it from
		// the database.
		NSEnumerator * enumerator = [messageList selectedRowEnumerator];
		NSNumber * rowIndex;
		
		[db beginTransaction];
		while ((rowIndex = [enumerator nextObject]) != nil)
		{
			VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[rowIndex integerValue]];
			if (![theRecord isRead])
				needFolderRedraw = YES;
			if ([db deleteMessage:[theRecord folderId] messageNumber:[theRecord messageId]])
				[arrayCopy removeObject:theRecord];
			
			// If this was our own message, add a withdraw command
			// FUTURE: if we're the moderator of this conference, withdraw it too.
			if ([[cixCredentials username] isEqualToString:[theRecord sender]])
			{
#warning 64BIT: Check formatting arguments
				NSString * messageString = [NSString stringWithFormat:@"%d", [theRecord messageId]];
				NSString * folderPath = [db folderPathName:[theRecord folderId]];

				[db addTask:MA_TaskCode_WithdrawMessage actionData:messageString folderName:folderPath orderCode:MA_OrderCode_WithdrawMessage];
			}
		}
		[db commitTransaction];
		[currentArrayOfMessages release];
		currentArrayOfMessages = [arrayCopy retain];
		[arrayCopy release];

		// If any of the messages we deleted were unread then the
		// folder's unread count just changed.
		if (needFolderRedraw)
			[foldersTree updateFolder:currentFolderId recurseToParents:YES];
		
		// If we're in threaded mode we need to rethread
		// to catch cases where we deleted parents but not
		// children.
		if (showThreading)
			[self threadMessages];

		// Compute the new place to put the selection
		if (currentSelectedRow >= (NSInteger)[currentArrayOfMessages count])
			currentSelectedRow = [currentArrayOfMessages count] - 1;
		[self makeRowSelectedAndVisible:currentSelectedRow];
		[messageList reloadData];
	
		// Read and/or priority unread count may have changed
		[self updateStatusMessage];
		[self showPriorityUnreadCountOnApplicationIcon];
	}
}

/* markCurrentRead
 * Mark the "current selected" read.
 */
-(void)markCurrentRead
{
	if (currentSelectedRow >= 0)
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
		[db markMessageRead:[theRecord folderId] messageId:[theRecord messageId] isRead:YES];

		// Handle marking read in the search folder. Update the search folder's copy
		// of the message so we update the UI properly.
		if ([theRecord folderId] != currentFolderId)
		{
			[theRecord markRead:YES];
			[db flushFolder:[theRecord folderId]];
		}
		[messageList reloadData];

		// Marking a message read in a search folder - you want to update
		// the search folder AND the original message folder which may be visible.
		if ([theRecord folderId] != currentFolderId)
			[foldersTree updateFolder:[theRecord folderId] recurseToParents:YES];
		[foldersTree updateFolder:currentFolderId recurseToParents:YES];

		// The info bar has a count of unread messages so we need to
		// update that.
		[self updateStatusMessage];
		[self showPriorityUnreadCountOnApplicationIcon];
	}
}

/* toggleHideIgnoredMessages
 * Toggles whether ignored messages are shown or not.
 */
-(IBAction)toggleHideIgnoredMessages:(id)sender
{
	hideIgnoredMessages = !hideIgnoredMessages;
	[[NSUserDefaults standardUserDefaults] setBool:hideIgnoredMessages forKey:MAPref_HideIgnoredMessages];
	[self refreshFolder:YES];
}

/* togglePlainText
 * Toggle whether messages are displayed in plain text.
 */
-(IBAction)togglePlainText:(id)sender
{
	showPlainText = !showPlainText;
	[[NSUserDefaults standardUserDefaults] setBool:showPlainText forKey:MAPref_ShowPlainText];
	if (currentSelectedRow != -1)
		[self updateMessageText];
}

/* toggleWindowsCP
 * Toggle display of the current message in the Windows code page.
 */
-(IBAction)toggleWindowsCP:(id)sender
{
	return;  // DJE
	showWindowsCP = !showWindowsCP;
	[[NSUserDefaults standardUserDefaults] setBool:showWindowsCP forKey:MAPref_ShowWindowsCP];
	if (currentSelectedRow != -1)
		[self updateMessageText];
}

/* toggleThreading
 * Toggle whether or not we display messages by thread.
 * (Because threading relies on the messages in currentArrayOfMessages being in ascending numerical
 *  order, we need to explicitly verify this is the case and do a pre-sort if not.)
 */
-(IBAction)toggleThreading:(id)sender
{
	showThreading = !showThreading;
	if (showThreading && sortColumnTag != MA_ID_MessageId)
	{
		sortDirection = 1;
		sortColumnTag = MA_ID_MessageId;
		[self sortMessages];
	}
		
	[[NSUserDefaults standardUserDefaults] setBool:showThreading forKey:MAPref_ShowThreading];
	[self refreshFolder:NO];
}

/* showTasksWindow
 * Display the tasks window.
 */
-(IBAction)showTasksWindow:(id)sender
{
	if (!tasksWindow)
		tasksWindow = [[TasksWindow alloc] init];
	[tasksWindow setDatabase:db];
	[tasksWindow showWindow:self];
}

/* toggleActivityViewer
 * Toggle display of the activity viewer during a connect.
 */
-(IBAction)toggleActivityViewer:(id)sender
{	
	NSWindow * activityWindow = [activityViewer window];
	if (![activityWindow isVisible])
		[activityViewer showWindow:self];
	else
		[activityWindow close];
}

/* viewOutbox
 * Switch to and view the contents of the Out Basket folder.
 */
-(IBAction)viewOutbox:(id)sender
{
	[foldersTree selectFolder:MA_Outbox_NodeID];
}

/* viewDrafts
 * Switch to and view the contents of the Drafts folder.
 */
-(IBAction)viewDrafts:(id)sender
{
	[foldersTree selectFolder:MA_Draft_NodeID];
}

/* viewNextUnread
 * Moves the selection to the next unread message.
 */
-(IBAction)viewNextUnread:(id)sender
{
	[self markCurrentRead];

	// Set focus back to message list
	[mainWindow makeFirstResponder:messageList];

	// Scan the current folder from the selection forward. If nothing found, try
	// other folders until we come back to ourselves.
	if (![self viewNextUnreadInCurrentFolder:[messageList selectedRow] isPriority:NO])
	{
		NSInteger nextFolderWithUnread = [foldersTree nextFolderWithUnread:currentFolderId isPriority:NO];
		if (nextFolderWithUnread != -1)
		{
			if (nextFolderWithUnread != currentFolderId)
			{
				selectAtEndOfReload = MA_Select_Unread;
				[foldersTree selectFolder:nextFolderWithUnread];
			}
			else
			{
				if (![self viewNextUnreadInCurrentFolder:-1 isPriority:NO])
					[self runOKAlertSheet:NSLocalizedString(@"No more unread messages", nil) text:NSLocalizedString(@"No more unread body", nil)];
			}
		}
	}
}

/* viewNextPriorityUnread
 * Moves the selection to the next priority unread message.
 */
-(IBAction)viewNextPriorityUnread:(id)sender
{
	if (currentSelectedRow >= 0)
	{
		// Only mark the current one read if it was a priority message
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
		if ([theRecord isPriority])
			[self markCurrentRead];
	}

	// Scan the current folder from the selection forward. If nothing found, try
	// other folders until we come back to ourselves.
	if (![self viewNextUnreadInCurrentFolder:[messageList selectedRow] isPriority:YES])
	{
		NSInteger nextFolderWithUnread = [foldersTree nextFolderWithUnread:currentFolderId isPriority:YES];
		if (nextFolderWithUnread != -1)
		{
			if (nextFolderWithUnread != currentFolderId)
			{
				selectAtEndOfReload = MA_Select_Priority;
				[foldersTree selectFolder:nextFolderWithUnread];
			}
			else
			{
				if (![self viewNextUnreadInCurrentFolder:-1 isPriority:YES])
					[self runOKAlertSheet:NSLocalizedString(@"No more priority unread messages", nil) text:NSLocalizedString(@"No more priority unread body", nil)];
			}
		}
	}
}

/* viewNextUnreadInCurrentFolder
 * Select the next unread message in the current folder after currentRow.
 */
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow isPriority:(BOOL)priorityFlag
{
	NSInteger totalRows = [currentArrayOfMessages count];
	if (currentRow < totalRows - 1)
	{
		VMessage * theRecord;
		
		do {
			theRecord = [currentArrayOfMessages objectAtIndex:++currentRow];
			if (![theRecord isRead])
			{
				if (!priorityFlag || (priorityFlag && [theRecord isPriority]))
				{
					[self makeRowSelectedAndVisible:currentRow];
					return YES;
				}
			}
		} while (currentRow < totalRows - 1);
	}
	return NO;
}

/* selectFirstUnreadInFolder
 * Moves the selection to the first unread message in the current message list or the
 * last message if the folder has no unread messages.
 */
-(void)selectFirstUnreadInFolder
{
	if (![self viewNextUnreadInCurrentFolder:-1 isPriority:NO])
		[self makeRowSelectedAndVisible:[currentArrayOfMessages count] - 1];
}

/* selectFirstUnreadPriorityInFolder
 * Moves the selection to the first unread priority message in the current message list or the
 * last message if the folder has no unread priority messages.
 */
-(void)selectFirstUnreadPriorityInFolder
{
	if (![self viewNextUnreadInCurrentFolder:-1 isPriority:YES])
		[self makeRowSelectedAndVisible:[currentArrayOfMessages count] - 1];
}

/* selectFolderAndMessage
 */
-(BOOL)selectFolderAndMessage:(NSInteger)folderId messageNumber:(NSInteger)messageNumber
{
	if (folderId == currentFolderId)
		return [self scrollToMessage:messageNumber];

	// OK, it gets a little harder here.
	selectAtEndOfReload = messageNumber;
	[foldersTree selectFolder:folderId];
	return [self scrollToMessage:messageNumber];
}

/* refreshFolder
 * Refreshes the current folder by applying the current sort or thread
 * logic and redrawing the message list. The selected message is preserved
 * and restored on completion of the refresh.
 */
-(void)refreshFolder:(BOOL)reloadData
{
	NSInteger messageNumber = -1;

	if (currentSelectedRow >= 0)
		messageNumber = [[currentArrayOfMessages objectAtIndex:currentSelectedRow] messageId];
	if (reloadData)
	{
		[currentArrayOfMessages release];
		currentArrayOfMessages = nil;
		[infoBarView update:nil database:db];
		[self startProgressIndicator];
		currentArrayOfMessages = [[db arrayOfMessages:currentFolderId filterString:@"" withoutIgnored:hideIgnoredMessages sorted:&sortedFlag] retain];
		[self stopProgressIndicator];
	}
	if (showThreading)
		[self threadMessages];
	else
		[self sortMessages];
	[self showSortDirection];
	[messageList reloadData];
	if (requestedMessage > 0)
		messageNumber = requestedMessage;
	if (messageNumber >= 0)
	{
		if (![self scrollToMessage:messageNumber])
			currentSelectedRow = -1;
		else
			[self updateMessageText];
	}
}

-(IBAction)cancelModAddtopic:(id)sender
{
	[modAddTopicWindow orderOut:sender];
	[NSApp endSheet:modAddTopicWindow returnCode:NSCancelButton];
}

-(IBAction)okModAddtopic:(id)sender
{
	[modAddTopicWindow orderOut:sender];
	[NSApp endSheet:modAddTopicWindow returnCode:NSOKButton];
}

-(void)modTopicSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Get the full path of the folder
	NSInteger folderId = [foldersTree actualSelection];
	NSString * folderPath = [db folderPathName:folderId];

	// Get stuff from sheet
	NSString * topicName = [modAddtopicTopicname stringValue];
	NSString * topicDescription = [modAddtopicDescription stringValue];
	BOOL seedMessage = [modAddtopicSeedMessage state];
	BOOL hasFiles = [modAddtopicHasFiles state];
	
	// Data for Task is "topic:[YN]:description"
	NSString * topicInfo = [NSString stringWithFormat:@"%@:%c:%@", topicName, hasFiles?'Y':'N', topicDescription];
	
	// Create a task to do it
	[db addTask:MA_TaskCode_ModAddTopic actionData:topicInfo folderName:folderPath orderCode:MA_OrderCode_Mod];

	// Also create a seed message if requested
	if (seedMessage)
	{
		// Put new topic name on end of conf name to make new topic path
		NSString *confName = [modAddtopicConfname stringValue];
		NSString * newTopic = [NSString stringWithFormat:@"%@/%@", confName, topicName];
		
		MessageWindow * msgWindow;
		
		msgWindow = [[MessageWindow alloc] initNewMessage:db recipient:newTopic commentNumber:(NSInteger)0 initialText: @"Seed message"];
		[[msgWindow window] makeKeyAndOrderFront:self];
	}
}

-(IBAction)cancelModUsername:(id)sender
{
	[modUsernameWindow orderOut:sender];
	[NSApp endSheet:modUsernameWindow returnCode:NSCancelButton];
}

-(IBAction)okModUsername:(id)sender
{
	[modUsernameWindow orderOut:sender];
	[NSApp endSheet:modUsernameWindow returnCode:NSOKButton];
}

-(void)modSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSString * username = [modUsernameText stringValue];

	if (returnCode == NSOKButton)
	{
		// Get the full path of the folder
		NSInteger folderId = [foldersTree actualSelection];
		NSString * folderPath = [db folderPathName:folderId];
		
		// Create a task to do it
		[db addTask:(NSInteger)contextInfo actionData:username folderName:folderPath orderCode:MA_OrderCode_Mod];
	}
}


// Menu options for Moderator functions
-(IBAction)modAddParticipant:(id)sender
{
	[modUsernameTitle setStringValue: @"Add Participant"];

	// Fire up the sheet
	[NSApp beginSheet:modUsernameWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(modSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:(void *)MA_TaskCode_ModAddPart];
}	

-(IBAction)modRemParticipant:(id)sender
{
	[modUsernameTitle setStringValue: @"Remove Participant"];
	
	// Fire up the sheet
	[NSApp beginSheet:modUsernameWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(modSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:(void *)MA_TaskCode_ModRemPart];
}	

-(IBAction)modComod:(id)sender
{
	[modUsernameTitle setStringValue: @"Add Co-Mod"];
	
	// Fire up the sheet
	[NSApp beginSheet:modUsernameWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(modSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:(void *)MA_TaskCode_ModComod];
	
}	

-(IBAction)modExmod:(id)sender
{
	[modUsernameTitle setStringValue: @"Remove Co-Mod"];
	
	// Fire up the sheet
	[NSApp beginSheet:modUsernameWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(modSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:(void *)MA_TaskCode_ModExmod];
	
}	

-(IBAction)modReadonly:(id)sender
{
	// Get the full path of the folder
	NSInteger folderId = [foldersTree actualSelection];
	NSString * folderPath = [db folderPathName:folderId];
#warning 64BIT: Check formatting arguments
	NSString * alertBody = [NSString stringWithFormat:NSLocalizedString(@"Toggle Topic %@?", nil), folderPath];

	// Get confirmation first
	NSInteger returnCode;
	returnCode = NSRunAlertPanel(NSLocalizedString(@"Toggle Readonly", nil), alertBody, NSLocalizedString(@"Yes", nil), NSLocalizedString(@"Cancel", nil), nil);
	if (returnCode == NSAlertAlternateReturn)
		return;
	
	// Create a task to change the folder on the service
	[db addTask:MA_TaskCode_ModRdOnly actionData:@"" folderName:folderPath orderCode:MA_OrderCode_Mod];
}

-(IBAction)modAddTopic:(id)sender
{
	// Add conf name (without topic) to sheet 
	NSInteger folderId = [foldersTree actualSelection];
	NSString * folderPath = [db folderPathName:folderId];
	NSArray *bits = [folderPath pathComponents];
	
	[modAddtopicConfname setStringValue:[bits objectAtIndex: 0]];
	
	// Fire up the sheet
	[NSApp beginSheet:modAddTopicWindow
	   modalForWindow:mainWindow 
		modalDelegate:self 
	   didEndSelector:@selector(modTopicSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}	

-(IBAction)modNewConference:(id)sender
{
	//PJC TODO:
}	


/* setMainWindowTitle
 * Updates the main window title bar.
 */
-(void)setMainWindowTitle:(NSInteger)folderId
{
	NSMutableString * newTitleString = [NSMutableString stringWithFormat:@"%@", [db folderPathName:folderId]];
	Folder * folder = [db folderFromID:folderId];
	if (IsFolderLocked(folder))
		[newTitleString appendString:@" (Read Only)"];
	[mainWindow setTitle:newTitleString];
	[headerBarView setCurrentFolder:db folderId:folderId];
}

/* selectFolderWithFilter
 * Switches to the specified folder and displays messages filtered by the given
 * searchFilter.
 */
-(void)selectFolderWithFilter:(NSInteger)newFolderId searchFilter:(NSString *)searchFilter
{
	[self setMainWindowTitle:newFolderId];
	[db flushFolder:currentFolderId];
	[messageList deselectAll:self];
	currentFolderId = newFolderId;
	[self showColumnsForFolder:currentFolderId];
	[currentArrayOfMessages release];
	currentArrayOfMessages = nil;
	[infoBarView update:nil database:db];
	[self startProgressIndicator];
	currentArrayOfMessages = [[db arrayOfMessages:currentFolderId filterString:searchFilter withoutIgnored:hideIgnoredMessages sorted:&sortedFlag] retain];
	if (showThreading)
		[self threadMessages];
	else
		[self sortMessages];
	[self updateStatusMessage];
	[messageList reloadData];
	[self selectMessageAfterReload];
	[self stopProgressIndicator];
	[mainWindow makeFirstResponder:messageList];
}

/* selectMessageAfterReload
 */
-(void)selectMessageAfterReload
{
	if (selectAtEndOfReload != MA_Select_None)
	{
		if (selectAtEndOfReload == MA_Select_Priority)
			[self selectFirstUnreadPriorityInFolder];
		else if (selectAtEndOfReload == MA_Select_Unread)
			[self selectFirstUnreadInFolder];
		else
			[self scrollToMessage:selectAtEndOfReload];
	}
	selectAtEndOfReload = MA_Select_Unread;
}

/* markAllRead
 * Mark all messages in the current folder read.
 */
-(IBAction)markAllRead:(id)sender
{
	NSInteger folderId = [foldersTree actualSelection];
	NSAssert(folderId > MA_Max_Reserved_NodeID, @"Trying to call markAllRead on an invalid folder");
	[self startProgressIndicator];
	[db markFolderRead:folderId];

	[foldersTree updateFolder:folderId recurseToParents:YES];
	[messageList reloadData];

	// The info bar has a count of unread messages so we need to
	// update that.
	[self updateStatusMessage];
	[self showPriorityUnreadCountOnApplicationIcon];
	[self stopProgressIndicator];
}

// Legal flags for markedMessageRange. Make sure that if you add a new flag
// here, you update the assert in markedMessageRange.
#define Range_Thread			0x02
#define Range_ThreadFromRoot	0x04
#define Range_Selected			0x08

/* markedMessageRange
 * Retrieve an array of messages to be used by the mark functions.
 *
 * If just one message is selected, we return that message and all child threads.
 * If a range of messages are selected, we return all the selected messages.
 */
-(NSArray *)markedMessageRange:(NSUInteger)flags
{
	NSAssert(flags & (Range_Thread|Range_ThreadFromRoot|Range_Selected), @"Illegal flags passed to markedMessageRange");
	NSArray * messageArray = nil;

	if ([messageList numberOfSelectedRows] == 1 && (flags & (Range_Thread|Range_ThreadFromRoot)))
	{
		NSInteger rowIndex = [messageList selectedRow];
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:rowIndex];

		if (flags & Range_ThreadFromRoot)
		{
			while ([theRecord level] > 0 && rowIndex)
				theRecord = [currentArrayOfMessages objectAtIndex:--rowIndex];
		}
		messageArray = [[db arrayOfChildMessages:[theRecord folderId] messageId:[theRecord messageId]] retain];
	}

	else if ([messageList numberOfSelectedRows] > 0 && (flags & Range_Selected))
	{
		NSEnumerator * enumerator = [messageList selectedRowEnumerator];
		NSMutableArray * newArray = [[NSMutableArray alloc] init];
		NSNumber * rowIndex;
		
		while ((rowIndex = [enumerator nextObject]) != nil)
			[newArray addObject:[currentArrayOfMessages objectAtIndex:[rowIndex integerValue]]];
		messageArray = [newArray retain];
		[newArray release];
	}
	return messageArray;
}

/* markPriority
 * Mark the selected messages priority or normal. If just one message is
 * selected, we toggle the state of that message and all child messgaes. If
 * multiple messages are selected, we toggle the state of just those messages.
 */
-(IBAction)markPriority:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_Thread|Range_Selected];
		[self markPriorityByArray:messageArray priorityFlag:![theRecord isPriority]];
		[messageArray release];
	}
}

/* markThreadFromRootPriority
 * Toggle the priority state of the entire thread from the root
 * message.
 */
-(IBAction)markThreadFromRootPriority:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_ThreadFromRoot];
		[self markPriorityByArray:messageArray priorityFlag:![theRecord isPriority]];
		[messageArray release];
	}
}

/* markPriorityByArray
 * Helper function used by both markRead and markThreadRead. Takes as an input an array
 * of messages and marks those messages read or unread.
 */
-(void)markPriorityByArray:(NSArray *)messageArray priorityFlag:(BOOL)priorityFlag
{
	VMessage * theRecord;
	NSUInteger arrayIndex = 0;
	
	[db beginTransaction];
	while (arrayIndex < [messageArray count])
	{
		theRecord = [messageArray objectAtIndex:arrayIndex];
		[db markMessagePriority:[theRecord folderId] messageId:[theRecord messageId] isPriority:priorityFlag];
		[theRecord markPriority:priorityFlag];
		++arrayIndex;
	}
	[db commitTransaction];
	[messageList reloadData];

	// We may have marked a unread message priority, so...
	[self showPriorityUnreadCountOnApplicationIcon];
}

/* markThreadFromRootIgnored
 * Toggle the ignored state of the entire thread from the root
 * message.
 */
-(IBAction)markThreadFromRootIgnored:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_ThreadFromRoot];
		[self markIgnoredByArray:messageArray ignoreFlag:![theRecord isIgnored]];
		[messageArray release];
	}
}

/* markIgnored
 * Mark the selected messages ignored or not ignored. If just one message is
 * selected, we toggle the state of that message and all child messgaes. If
 * multiple messages are selected, we toggle the state of just those messages.
 */
-(IBAction)markIgnored:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_Thread|Range_Selected];
		[self markIgnoredByArray:messageArray ignoreFlag:![theRecord isIgnored]];
		[messageArray release];
	}
}

/* markIgnoredByArray
 * Helper function used by both markRead and markThreadRead. Takes as an input an array
 * of messages and marks those messages read or unread.
 */
-(void)markIgnoredByArray:(NSArray *)messageArray ignoreFlag:(BOOL)ignoreFlag
{
	VMessage * theRecord;
	NSMutableArray * arrayCopy = [[NSMutableArray alloc] initWithArray:currentArrayOfMessages];
	NSUInteger arrayIndex = 0;

	[db beginTransaction];
	while (arrayIndex < [messageArray count])
	{
		theRecord = [messageArray objectAtIndex:arrayIndex];
		[db markMessageIgnored:[theRecord folderId] messageId:[theRecord messageId] isIgnored:ignoreFlag];
		[theRecord markIgnored:ignoreFlag];
		if (ignoreFlag && hideIgnoredMessages)
			[arrayCopy removeObject:theRecord];
		++arrayIndex;
	}
	[db commitTransaction];
	[currentArrayOfMessages release];
	currentArrayOfMessages = [arrayCopy retain];
	[arrayCopy release];
	
	if (currentSelectedRow >= (NSInteger)[currentArrayOfMessages count])
		currentSelectedRow = [currentArrayOfMessages count] - 1;
	[infoBarView update:nil database:db];
	[self refreshFolder:NO];
}

/* markThreadRead
 * Marks the thread from the current message as read then skip to the
 * next unread message.
 */
-(IBAction)markThreadRead:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		NSArray * messageArray = [self markedMessageRange:Range_Thread];
		[self markReadByArray:messageArray readFlag:YES];
		[messageArray release];
	}
}

/* markThreadFromRootRead
 * Toggle the read/unread state of the entire thread from the root
 * message.
 */
-(IBAction)markThreadFromRootRead:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_ThreadFromRoot];
		[self markReadByArray:messageArray readFlag:![theRecord isRead]];
		[messageArray release];
	}
}

/* markRead
 * Toggle the read/unread state of the selected message
 */
-(IBAction)markRead:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_Selected];
		[self markReadByArray:messageArray readFlag:![theRecord isRead]];
		[messageArray release];
	}
}

/* markReadByArray
 * Helper function used by both markRead and markThreadRead. Takes as an input an array
 * of messages and marks those messages read or unread.
 */
-(void)markReadByArray:(NSArray *)messageArray readFlag:(BOOL)readFlag
{
	NSEnumerator * enumerator = [messageArray objectEnumerator];
	VMessage * theRecord;
	NSInteger lastFolderId = -1;
	NSInteger folderId;

	[db beginTransaction];
	while ((theRecord = [enumerator nextObject]) != nil)
	{
		folderId = [theRecord folderId];
		[db markMessageRead:folderId messageId:[theRecord messageId] isRead:readFlag];
		if (folderId != currentFolderId)
		{
			[theRecord markRead:readFlag];
			[db flushFolder:folderId];
		}
		if (folderId != lastFolderId && lastFolderId != -1)
			[foldersTree updateFolder:lastFolderId recurseToParents:YES];
		lastFolderId = folderId;
	}
	[db commitTransaction];
	[messageList reloadData];
	
	if (lastFolderId != -1)
		[foldersTree updateFolder:lastFolderId recurseToParents:YES];
	[foldersTree updateFolder:currentFolderId recurseToParents:YES];
	
	// The info bar has a count of unread messages so we need to
	// update that.
	[self updateStatusMessage];
	[self showPriorityUnreadCountOnApplicationIcon];
}

/* markFlagged
 * Toggle the flagged/unflagged state of the selected message
 */
-(IBAction)markFlagged:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_Selected];
		[self markFlaggedByArray:messageArray flagged:![theRecord isFlagged]];
		[messageArray release];
	}
}

/* markThreadFromRootFlagged
 * Toggle the flagged/unflagged state of the entire thread from the root
 * message.
 */
-(IBAction)markThreadFromRootFlagged:(id)sender
{
	if ([messageList selectedRow] != -1 && ![db readOnly])
	{
		VMessage * theRecord = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
		NSArray * messageArray = [self markedMessageRange:Range_ThreadFromRoot];
		[self markFlaggedByArray:messageArray flagged:![theRecord isFlagged]];
		[messageArray release];
	}
}

/* markFlaggedByArray
 * Mark the specified messages in messageArray as flagged.
 */
-(void)markFlaggedByArray:(NSArray *)messageArray flagged:(BOOL)flagged
{
	NSEnumerator * enumerator = [messageArray objectEnumerator];
	VMessage * theRecord;

	[db beginTransaction];
	while ((theRecord = [enumerator nextObject]) != nil)
	{
		[theRecord markFlagged:flagged];
		[db markMessageFlagged:[theRecord folderId] messageId:[theRecord messageId] isFlagged:flagged];
	}
	[db commitTransaction];
	[messageList reloadData];
}

/* viewProfile
 * Display the profile for the current user if there is one.
 */
-(IBAction)viewProfile:(id)sender
{
	if (!profileWindow)
		profileWindow = [[Profile alloc] initWithDatabase:db];
	[profileWindow showWindow:self];
	if (currentSelectedRow >= 0)
	{
		VMessage *message = [currentArrayOfMessages objectAtIndex:currentSelectedRow];
		NSString * personName = [message sender];
		VPerson * person = [personManager personFromPerson:personName];
		[profileWindow setCurrentPerson:person];
		// static analyser complains
		// [person release];
	}
}

/* joinConference
 * Join a CIX conference.
 */
-(IBAction)joinConference:(id)sender
{
	if (!joinWindow)
		joinWindow = [[Join alloc] initWithDatabase:db];
	[joinWindow joinCIXConference:mainWindow initialConferenceName:nil];
}

-(IBAction)setCIXBack:(id)sender
{
	[db addTask:MA_TaskCode_SetCIXBack actionData:(NSString *)@"1" folderName:@"cixnews/information" orderCode:MA_OrderCode_SetCIXBack];
	[self setStatusMessage:@"CIX will be set back by one day."];
}

-(IBAction)copyUrl:(id)sender
{
	VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:[messageList selectedRow]];
	Folder * srcFolder = [db folderFromID:[thisMessage folderId]];
	NSString *url;
	
	if (IsRSSFolder(srcFolder))
	{
		RSSFolder * rssFolder = [db rssFolderFromId:[thisMessage folderId]];
		url = [rssFolder subscriptionURL];
	}
	else
	{
#warning 64BIT: Check formatting arguments
		url = [NSString stringWithFormat:@"cix:%@:%d",[db folderPathName:[thisMessage folderId]], [thisMessage messageId]];
	}

	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes: [NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setString:url forType:NSStringPboardType];
}

/* renameFolder
 * Renames the current folder
 */
-(IBAction)renameFolder:(id)sender
{
	Folder * folder = [db folderFromID:[foldersTree actualSelection]];
	if (IsRSSFolder(folder) || IsSearchFolder(folder))
	{
		// Initialise field
		[renameField setStringValue:[folder name]];
		[renameWindow makeFirstResponder:renameField];

		[NSApp beginSheet:renameWindow
		   modalForWindow:mainWindow 
			modalDelegate:self 
		   didEndSelector:nil 
			  contextInfo:nil];
	}
}

/* endRenameFolder
 * Called when the user OK's the Rename Folder sheet
 */
-(IBAction)endRenameFolder:(id)sender
{
	[renameWindow orderOut:sender];
	[NSApp endSheet:renameWindow returnCode:1];
	[db setFolderName:currentFolderId newName:[renameField stringValue]];
}

/* cancelRenameFolder
 * Called when the user cancels the Rename Folder sheet
 */
-(IBAction)cancelRenameFolder:(id)sender
{
	[renameWindow orderOut:sender];
	[NSApp endSheet:renameWindow returnCode:0];
}

/* deleteFolder
* Delete the current folder.
*/
-(IBAction)deleteFolder:(id)sender
{
	NSInteger folderId = [foldersTree actualSelection];
#warning 64BIT: Check formatting arguments
	NSAssert1(folderId > MA_Max_Reserved_NodeID, @"Ouch! Attempting to delete a built-in folder %d", folderId);
	
	// Get the full path of the folder we're deleting.
	NSString * folderPath = [db folderPathName:folderId];
	
	// Handle search folders especially
	Folder * folder = [db folderFromID:folderId];
	
	// If it is a search folder, the text is slightly different
	NSString * alertBody;
	NSString * alertTitle;
	
	if (IsSearchFolder(folder))
	{
#warning 64BIT: Check formatting arguments
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete smart folder text", nil), folderPath];
		alertTitle = NSLocalizedString(@"Delete smart folder", nil);
	}
	else if (IsRSSFolder(folder))
	{
#warning 64BIT: Check formatting arguments
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete RSS feed text", nil), [folder name]];
		alertTitle = NSLocalizedString(@"Delete RSS feed", nil);
	}
	else
	{
#warning 64BIT: Check formatting arguments
		alertBody = [NSString stringWithFormat:NSLocalizedString(@"Delete folder text", nil), folderPath];
		alertTitle = NSLocalizedString(@"Delete folder", nil);
	}
	
	// Get confirmation first
	NSInteger returnCode;
	returnCode = NSRunAlertPanel(alertTitle, alertBody, NSLocalizedString(@"Delete", nil), NSLocalizedString(@"Cancel", nil), nil);
	if (returnCode == NSAlertAlternateReturn)
		return;
	
	// Create a task to resign the folder on the service
	if (!IsSearchFolder(folder) && !IsRSSFolder(folder))
		[db addTask:MA_TaskCode_ResignFolder actionData:@"" folderName:folderPath orderCode:MA_OrderCode_ResignFolder];
	
	// Create a status string
#warning 64BIT: Check formatting arguments
	NSString * deleteStatusMsg = [NSString stringWithFormat:NSLocalizedString(@"Delete folder status", nil), folderPath];
	
	// Now call the database to delete the folder.
	[self startProgressIndicator];
	[self setStatusMessage:deleteStatusMsg];
	[db deleteFolder:folderId];
	[self setStatusMessage:nil];
	[self stopProgressIndicator];
	
	// Priority unread count may have changed
	[self showPriorityUnreadCountOnApplicationIcon];
}

/* resignFolder
* Resign from CIX but leave the folder intact.
*/
-(IBAction)resignFolder:(id)sender
{
	NSInteger folderId = [foldersTree actualSelection];
#warning 64BIT: Check formatting arguments
	NSAssert1(folderId > MA_Max_Reserved_NodeID, @"Ouch! Attempting to resign from a built-in folder %d", folderId);
	
	// Get the full path of the folder we're deleting.
	NSString * folderPath = [db folderPathName:folderId];
			
	// Get confirmation first
	NSInteger returnCode;
	returnCode = NSRunAlertPanel(NSLocalizedString(@"Resign", nil), NSLocalizedString(@"Resign Conference/Topic", nil), NSLocalizedString(@"Resign", nil), NSLocalizedString(@"Cancel", nil), nil);
	if (returnCode == NSAlertAlternateReturn)
		return;
	
	// Create a task to resign the folder on the service
	[db addTask:MA_TaskCode_ResignFolder actionData:@"" folderName:folderPath orderCode:MA_OrderCode_ResignFolder];
}

/* showAcknowledgements
 * Display the acknowledgements document in a browser.
 */
-(IBAction)showAcknowledgements:(id)sender
{
	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	NSString * pathToAckFile = [thisBundle pathForResource:@"Acknowledgements.rtf" ofType:@""];
	NSURL * acknowledgementURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"file://%@", pathToAckFile]];
	[[NSWorkspace sharedWorkspace] openURL:acknowledgementURL];
	[acknowledgementURL release];
}

/* searchUsingToolbarTextField
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchUsingToolbarTextField:(id)sender
{
    NSString* searchString = [sender stringValue];

	// A filtered list doesn't make much sense in thread mode so
	// we switch away from thread mode while we show the list and
	// set a flag to revert it when we finish. if the search string
	// is blank (because we clicked the X button to delete the current
	// search string, then restore the previous status.
	if ([searchString isEqualToString:@""])
	{
		if (reinstateThreading)
		{
			showThreading = YES;
			reinstateThreading = NO;
		}
	}
	else if (showThreading)
	{
		showThreading = NO;
		reinstateThreading = YES;
	}
	[self selectFolderWithFilter:currentFolderId searchFilter:searchString];
}

/* activityString
 * Writes the specified string to the activity window.
 */
-(void)activityString:(NSString *)string
{
	[activityViewer writeString:string];
}

/* startConnect
 * This delegate is called when a connection is started
 */
-(void)startConnect:(id)sender
{
}

/* taskStatus
 * Called when a task is completed.
 */
-(void)taskStatus:(BOOL)finished
{
	if (finished)
	{
		[self stopProgressIndicator];
		[self showPriorityUnreadCountOnApplicationIcon];
	}
	else
		[self startProgressIndicator];
}

/* endConnect
 * This delegate is called when a connection is completed
 */
-(void)endConnect:(NSNumber *)resultCode
{
	NSInteger result = [resultCode integerValue];
	switch (result)
	{
		case MA_Connect_Success: {
			// If Growl is available, send a notification if any new messages
			// were retrieved
			if ([connect messagesCollected] && growlAvailable)
			{
				NSNumber * defaultValue = [NSNumber numberWithBool:YES];
				NSNumber * stickyValue = [NSNumber numberWithBool:NO];
#warning 64BIT: Check formatting arguments
				NSString * msgText = [NSString stringWithFormat:NSLocalizedString(@"Growl description", nil), [connect messagesCollected]];

				NSDictionary *aNuDict = [NSDictionary dictionaryWithObjectsAndKeys:
					NSLocalizedString(@"Growl notification name", nil), GROWL_NOTIFICATION_NAME,
					NSLocalizedString(@"Growl notification title", nil), GROWL_NOTIFICATION_TITLE,
					msgText, GROWL_NOTIFICATION_DESCRIPTION,
					appName, GROWL_APP_NAME,
					defaultValue, GROWL_NOTIFICATION_DEFAULT,
					stickyValue, GROWL_NOTIFICATION_STICKY,
					nil];
				[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION 
																			   object:nil 
																			 userInfo:aNuDict
																   deliverImmediately:YES];
			}
			break;
			}

		case MA_Connect_Aborted:
			[self setStatusMessage:NSLocalizedString(@"The last connection was stopped before it was completed.", nil)];
			break;

		case MA_Connect_ServiceUnavailable:
			[self runOKAlertSheet:@"Could not connect to service"
							 text:@"Service unavailable text", [connect serviceString]];
			break;

		case MA_Connect_AlreadyConnected:
			[self runOKAlertSheet:@"Could not connect to service"
							 text:@"User already logged on text", [connect username]];
			break;

		case MA_Connect_BadPassword:
			[self runOKAlertSheet:@"Incorrect password"
							 text:@"Incorrect password text", [connect username]];
			break;

		case MA_Connect_BadUsername:
			[self runOKAlertSheet:@"Unrecognised user name"
							 text:@"Unrecognised user name text", [connect username]];
			break;
	}
}

/* runOKAlertSheet
 * Displays an alert sheet with just an OK button.
 */
-(void)runOKAlertSheet:(NSString *)titleString text:(NSString *)bodyText, ...
{
	NSString * fullBodyText;
	va_list arguments;

	va_start(arguments, bodyText);
#warning 64BIT: Check formatting arguments
	fullBodyText = [[NSString alloc] initWithFormat:NSLocalizedString(bodyText, nil) arguments:arguments];
#warning 64BIT: Check formatting arguments
	NSBeginAlertSheet(NSLocalizedString(titleString, nil),
					  NSLocalizedString(@"OK", nil),
					  nil,
					  nil,
					  mainWindow,
					  self,
					  nil,
					  nil, nil,
					  fullBodyText);
	[fullBodyText release];
	va_end(arguments);
}

/* setStatusMessage
 * Sets a new status message for the info bar then updates the view. To remove
 * any existing status message, pass nil as the value.
 */
-(void)setStatusMessage:(NSString *)newStatusText
{
	[newStatusText retain];
	[statusText release];
	statusText = newStatusText;
	[self updateStatusMessage];
}

/* updateStatusMessage
 */
-(void)updateStatusMessage
{
	[headerBarView setFolderCount:[currentArrayOfMessages count]];
	[headerBarView refreshForCurrentFolder];
	if (statusText != nil)
		[infoString setStringValue:statusText];
	else
		[infoString setStringValue:@""];
	[infoString displayIfNeeded];
}

/* startProgressIndicator
 * Gets the progress indicator on the info bar running. Because this can be called
 * nested, we use progressCount to make sure we remove it at the right time.
 */
-(void)startProgressIndicator
{
	if (progressCount++ == 0)
		[spinner startAnimation:self];
}

/* stopProgressIndicator
 * Stops the progress indicator on the info bar running
 */
-(void)stopProgressIndicator
{
	NSAssert(progressCount > 0, @"Called stopProgressIndicator without a matching startProgressIndicator");
	if (--progressCount < 1)
	{
		[spinner stopAnimation:self];
		progressCount = 0;
	}
}

/* validateCommonToolbarAndMenuItems
 * Validation code for items that appear on both the toolbar and the menu. Since these are
 * handled identically, we validate here to avoid duplication of code in two delegates.
 * The return value is YES if we handled the validation here and no further validation is
 * needed, NO otherwise.
 */
-(BOOL)validateCommonToolbarAndMenuItems:(SEL)theAction validateFlag:(BOOL *)validateFlag
{
	BOOL isBusy = [self isBusy];
	if (theAction == @selector(printDocument:))
	{
		*validateFlag = ([messageList selectedRow] >= 0);
		return YES;
	}
	else if (theAction == @selector(viewProfile:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		*validateFlag = ([messageList selectedRow] >= 0) && !IsRSSFolder(folder) && (folderId != MA_Draft_NodeID && folderId != MA_Outbox_NodeID);
		return YES;
	}
	else if (theAction == @selector(backTrackMessage:))
	{
		*validateFlag = ![backtrackArray isAtStartOfQueue] && !isBusy;
		return YES;
	}
	else if (theAction == @selector(forwardTrackMessage:))
	{
		*validateFlag = ![backtrackArray isAtEndOfQueue] && !isBusy;
		return YES;
	}
	else if (theAction == @selector(newRSSSubscription:))
	{
		*validateFlag = !isBusy;
		return YES;
	}
	else if (theAction == @selector(newSearchFolder:))
	{
		*validateFlag = !isBusy;
		return YES;
	}
	else if (theAction == @selector(viewNextUnread:))
	{
		*validateFlag = !isBusy;
		return YES;
	}
	else if (theAction == @selector(markFlagged:))
	{
		// We return NO because validateMenuItem needs a chance to
		// change the label on the menu item whereas the toolbar
		// doesn't.
		NSInteger rowIndex = [messageList selectedRow];
		*validateFlag = (rowIndex != -1 && ![db readOnly] && !isBusy);
		return NO;
	}
	else if (theAction == @selector(goOnline:))
	{
		*validateFlag = !isOnlineMode;
		return YES;
	}
	else if (theAction == @selector(goOffline:))
	{
		*validateFlag = isOnlineMode;
		return YES;
	}
	else if (theAction == @selector(viewOutbox:))
	{
		*validateFlag = !isBusy;
		return YES;
	}
	else if (theAction == @selector(viewDrafts:))
	{
		*validateFlag = !isBusy;
		return YES;
	}
	else if (theAction == @selector(getMessages:))
	{
		*validateFlag = (connect == nil || ![connect isProcessing]) && !isBusy && ![db readOnly];
		return NO;
	}
	else if (theAction == @selector(replyToMessage:))
	{
		Folder * folder = [db folderFromID:currentFolderId];
		*validateFlag = !IsRSSFolder(folder) && [messageList selectedRow] != -1 && ![db readOnly] && !isBusy;
		return YES;
	}
	else if (theAction == @selector(newMessage:))
	{
		Folder * folder = [db folderFromID:currentFolderId];
		*validateFlag = !IsRSSFolder(folder) && ![db readOnly] && !isBusy;
		return YES;
	}
    return NO;
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	BOOL flag;
	[self validateCommonToolbarAndMenuItems:[toolbarItem action] validateFlag:&flag];
	return flag;
}

/* validateMenuItem
 * This is our override where we handle item validation for the
 * commands that we own.
 */
-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL	theAction = [menuItem action];
	BOOL isBusy = [self isBusy];
	BOOL flag;

	if ([self validateCommonToolbarAndMenuItems:theAction validateFlag:&flag])
	{
		return flag;
	}
	else if (theAction == @selector(togglePlainText:))
	{
		[menuItem setState:(showPlainText ? NSOnState : NSOffState)];
		return !isBusy;
	}
	else if (theAction == @selector(toggleWindowsCP:))
	{
		[menuItem setState:(showWindowsCP ? NSOnState : NSOffState)];
		return !isBusy;
	}
	else if (theAction == @selector(toggleThreading:))
	{
		[menuItem setState:(showThreading ? NSOnState : NSOffState)];
		return !isBusy;
	}
	else if (theAction == @selector(getMessages:))
	{
		if (connect && [connect isProcessing])
			[menuItem setTitle:NSLocalizedString(@"Stop Current Connect", nil)];
		else
			[menuItem setTitle:NSLocalizedString(@"Connect", nil)];
		return !isBusy && ![db readOnly];
	}
	else if (theAction == @selector(showPreferencePanel:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(showTasksWindow:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(checkForUpdates:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(gotoMessage:))
	{
		return [currentArrayOfMessages count] > 0 && !isBusy;
	}
	else if (theAction == @selector(viewNextPriorityUnread:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(originalThread:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return (folder != nil && IsSearchFolder(folder) && [messageList selectedRow] >= 0);
	}
	else if (theAction == @selector(originalMessage:))
	{
		NSInteger rowIndex = [messageList selectedRow];
		NSInteger comment = 0;
		if (rowIndex != -1)
		{
			VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
			comment = [thisMessage comment];
		}
		return (comment > 0);
	}
	else if (theAction == @selector(doViewColumn:))
	{
		VField * field = [menuItem representedObject];
		[menuItem setState:[field visible] ? NSOnState : NSOffState];
	}
	else if (theAction == @selector(toggleHideIgnoredMessages:))
	{
		[menuItem setState:hideIgnoredMessages ? NSOnState : NSOffState];
	}
	else if (theAction == @selector(doSortColumn:))
	{
		VField * field = [menuItem representedObject];
		if ([[field name] isEqualToString:sortColumnIdentifier] && !showThreading)
			[menuItem setState:NSOnState];
		else
			[menuItem setState:NSOffState];
	}
	else if (theAction == @selector(deleteFolder:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		return (folderId != [db rssNodeID]) && folderId > MA_Max_Reserved_NodeID && !isBusy;
	}
	else if (theAction == @selector(renameFolder:))
	{
		Folder * folder = [db folderFromID:[foldersTree actualSelection]];
		return IsRSSFolder(folder) || IsSearchFolder(folder);
	}
	else if (theAction == @selector(resignFolder:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return (folderId != [db rssNodeID] && (folderId > MA_Max_Reserved_NodeID || folderId == [db conferenceNodeID]) && !isBusy && !IsSearchFolder(folder) && !IsRSSFolder(folder));
	}
	else if (theAction == @selector(fillMessageGaps:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return (folderId != [db rssNodeID] && (folderId > MA_Max_Reserved_NodeID || folderId == [db conferenceNodeID]) && !isBusy && !IsSearchFolder(folder) && !IsRSSFolder(folder));
	}
	else if (theAction == @selector(editRSSSubscription:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return (!isBusy && folder != nil && IsRSSFolder(folder));
	}
	else if (theAction == @selector(editSearchFolder:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return (!isBusy && folder != nil && IsSearchFolder(folder));
	}
	else if (theAction == @selector(markAllRead:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		return (folderId > MA_Max_Reserved_NodeID) && !IsSearchFolder([db folderFromID:folderId]) && !isBusy;
	}
	else if (theAction == @selector(joinConference:))
	{
		return ![db readOnly] && !isBusy;
	}
	else if (theAction == @selector(importCIXScratchpad:))
	{
		return ![db readOnly] && !isBusy;
	}
	else if (theAction == @selector(exportCIXScratchpad:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return !isBusy && (folderId > MA_Max_Reserved_NodeID || folderId == [db conferenceNodeID]) && !IsRSSFolder(folder);
	}
	else if (theAction == @selector(importRSSSubscriptions:))
	{
		return ![db readOnly] && !isBusy;
	}
	else if (theAction == @selector(exportRSSSubscriptions:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(replyByMail:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return currentSelectedRow >= 0 && !IsRSSFolder(folder);
	}
	else if (theAction == @selector(toggleOnline:))
	{
		[menuItem setState:(isOnlineMode ? NSOnState : NSOffState)];
	}
	else if (theAction == @selector(compactDatabase:))
	{
		return !isBusy;
	}
	else if (theAction == @selector(deleteMessage:))
	{
		return [messageList selectedRow] != -1 && ![db readOnly] && !isBusy;
	}
	else if (theAction == @selector(markPriority:))
	{
		NSInteger rowIndex = [messageList selectedRow];
		if (rowIndex != -1)
		{
			VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
			if ([thisMessage isPriority])
				[menuItem setTitle:NSLocalizedString(@"Mark Normal", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Priority", nil)];
		}
		return (rowIndex != -1 && ![db readOnly] && !isBusy);
	}
	else if (theAction == @selector(markIgnored:))
	{
		NSInteger rowIndex = [messageList selectedRow];
		if (rowIndex != -1)
		{
			VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
			if ([thisMessage isIgnored])
				[menuItem setTitle:NSLocalizedString(@"Mark Unignored", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Ignored", nil)];
		}
		return (rowIndex != -1 && ![db readOnly] && !isBusy);
	}
	else if (theAction == @selector(markFlagged:))
	{
		NSInteger rowIndex = [messageList selectedRow];
		if (rowIndex != -1)
		{
			VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
			if ([thisMessage isFlagged])
				[menuItem setTitle:NSLocalizedString(@"Mark Unflagged", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Flagged", nil)];
		}
		return (rowIndex != -1 && ![db readOnly] && !isBusy);
	}
	else if (theAction == @selector(markThreadRead:))
	{
		return ([messageList selectedRow] != -1 && ![db readOnly] && !isBusy);
	}
	else if (theAction == @selector(markRead:))
	{
		NSInteger rowIndex = [messageList selectedRow];
		if (rowIndex != -1)
		{
			VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];
			if ([thisMessage isRead])
				[menuItem setTitle:NSLocalizedString(@"Mark Unread", nil)];
			else
				[menuItem setTitle:NSLocalizedString(@"Mark Read", nil)];
		}
		return (rowIndex != -1 && ![db readOnly] && !isBusy);
	}
	else if (theAction == @selector(modAddParticipant:) ||
			 theAction == @selector(modRemParticipant:) ||
			 theAction == @selector(modComod:) ||
			 theAction == @selector(modExmod:) ||
			 theAction == @selector(modReadonly:) ||
			 theAction == @selector(modAddTopic:) ||
			 theAction == @selector(uploadFile:) ||
			 theAction == @selector(downloadFile:))
	{
		NSInteger folderId = [foldersTree actualSelection];
		Folder * folder = [db folderFromID:folderId];
		return (folderId != [db rssNodeID] && (folderId > MA_Max_Reserved_NodeID || folderId == [db conferenceNodeID]) && !isBusy && !IsSearchFolder(folder) && !IsRSSFolder(folder));		
	}
	else if (theAction == @selector(modNewConference:)) 
	{
		return NO; // Not done this yet! but move above when finished
	}

	return YES;
}

/* itemForItemIdentifier
 * This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching NSToolbarItem.
 * It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
 * going to be displayed in a customization palette.
 */
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    if ([itemIdentifier isEqualToString:@"SearchItem"])
	{
		NSRect fRect = [searchView frame];
		[item setLabel:NSLocalizedString(@"Search Messages", nil)];
		[item setPaletteLabel:[item label]];
		[item setView:searchView];
		[item setMinSize:fRect.size];
		[item setMaxSize:fRect.size];
		[item setTarget:self];
		[item setAction:@selector(searchUsingToolbarTextField:)];
    }
	else if ([itemIdentifier isEqualToString:@"MarkAsFlagged"])
	{
        [item setLabel:NSLocalizedString(@"Flag", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"markAsFlagged.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(markFlagged:)];
	}
	else if ([itemIdentifier isEqualToString:@"ViewProfile"])
	{
		[item setLabel:NSLocalizedString(@"Profile", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"resume.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(viewProfile:)];
	}
	else if ([itemIdentifier isEqualToString:@"GetMessages"])
	{
		[item setLabel:NSLocalizedString(@"Connect", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"getMessages.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(getMessages:)];
	}
	else if ([itemIdentifier isEqualToString:@"GoOnline"])
	{
		[item setLabel:NSLocalizedString(@"Go Online", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"goOnline.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(goOnline:)];
	}
	else if ([itemIdentifier isEqualToString:@"GoOffline"])
	{
		[item setLabel:NSLocalizedString(@"Go Offline", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"goOffline.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(goOffline:)];
	}
	else if ([itemIdentifier isEqualToString:@"OutBoxFolder"])
	{
		[item setLabel:NSLocalizedString(@"Out Basket", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"outboxFolderButton.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(viewOutbox:)];
	}
	else if ([itemIdentifier isEqualToString:@"DraftFolder"])
	{
		[item setLabel:NSLocalizedString(@"Draft Folder", nil)];
		[item setPaletteLabel:[item label]];
		[item setImage:[NSImage imageNamed:@"draftFolderButton.tiff"]];
		[item setTarget:self];
		[item setAction:@selector(viewDrafts:)];
	}
	else if ([itemIdentifier isEqualToString:@"NewMessage"])
	{
        [item setLabel:NSLocalizedString(@"New Message", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"compose.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(newMessage:)];
	}
	else if ([itemIdentifier isEqualToString:@"NewRSSSubscription"])
	{
        [item setLabel:NSLocalizedString(@"Subscribe", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"newRSSSubscription.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(newRSSSubscription:)];
	}
	else if ([itemIdentifier isEqualToString:@"NewSmartFolder"])
	{
        [item setLabel:NSLocalizedString(@"Smart Folder", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"newSmartFolder.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(newSearchFolder:)];
	}
	else if ([itemIdentifier isEqualToString:@"ReplyToMessage"])
	{
        [item setLabel:NSLocalizedString(@"Reply", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"reply.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(replyToMessage:)];
	}
	else if ([itemIdentifier isEqualToString:@"NextUnread"])
	{
        [item setLabel:NSLocalizedString(@"Next Unread", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"nextunread.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(viewNextUnread:)];
	}
	return [item autorelease];
}

/* toolbarDefaultItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
 * set of toolbar items.  It can also be called by the customization palette to display the default toolbar.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:@"NewRSSSubscription",
									 @"NewSmartFolder",
									 NSToolbarPrintItemIdentifier,
									 @"NewMessage",
									 @"ReplyToMessage",
									 @"MarkAsFlagged",
									 @"GetMessages",
									 NSToolbarSpaceItemIdentifier,
									 @"SearchItem",
									 nil];
}

/* toolbarAllowedItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
 * toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
									 NSToolbarSpaceItemIdentifier,
									 NSToolbarFlexibleSpaceItemIdentifier,
									 NSToolbarPrintItemIdentifier,
									 @"NewRSSSubscription",
									 @"NewSmartFolder",
									 @"MarkAsFlagged",
									 @"GetMessages",
									 @"NewMessage",
									 @"ReplyToMessage",
									 @"SearchItem",
									 @"OutBoxFolder",
									 @"DraftFolder",
									 @"GoOnline",
									 @"GoOffline",
									 @"NextUnread",
									 @"ViewProfile",
									 nil];
}

/* writeRows
 * Called to initiate a drag from MessageListView
 */
-(BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	NSUInteger msgnum;
	NSMutableString *newtext = [NSMutableString stringWithString:@""];
	
	// Set up the pasteboard	
	[pboard declareTypes:[NSArray arrayWithObjects: NSStringPboardType, nil] owner:self];

	// Get all the messages that are being dragged
	for (msgnum = 0; msgnum < [rows count]; msgnum++)
	{
		// Get the message ID being dragged
		NSInteger rowIndex = [[rows objectAtIndex: msgnum] integerValue];
		VMessage * thisMessage = [currentArrayOfMessages objectAtIndex:rowIndex];

		// Can't drag from pseudo folders.
		if ([thisMessage folderId] <= MA_Max_Reserved_NodeID)
			return NO;
       
		// Get the text if it's not already in memory.
		if ([thisMessage text] == nil)
			[thisMessage setText:[db messageText:[thisMessage folderId] messageId:[thisMessage messageId]]];

		// Get the message date formatted
		NSCalendarDate * dateFormatter = [[thisMessage date] dateWithCalendarFormat:nil timeZone:nil];
		
		// If we're copying to a CIX topic from an RSS folder, we need to strip the HTML and
		// reformat as ASCII.
		NSString * text = [thisMessage text];
		Folder * srcFolder = [db folderFromID:[thisMessage folderId]];
		if (IsRSSFolder(srcFolder))
		{
			// deprecated API was hare DJE
			NSData * textData = [[NSData alloc] 
								 initWithBytes:[text
												cStringUsingEncoding:NSWindowsCP1252StringEncoding]
								 length:[text length]];
			NSAttributedString * attrString = [[NSAttributedString alloc] initWithHTML:textData documentAttributes:nil];
			[newtext appendFormat: @"%@\n", [attrString string]];
			[attrString release];
			[textData release];
		}
		else if ([thisMessage comment])
		{
#warning 64BIT: Check formatting arguments
			[newtext appendFormat: @"**COPIED FROM: >>>%@ %d %@(%d)%@ c%d\n%@\n", 
								[db folderPathName:[thisMessage folderId]],
								[thisMessage messageId],  [thisMessage sender],
								[text length],
								[dateFormatter descriptionWithCalendarFormat: @"%d%b%y %H:%M"], 
								[thisMessage comment],
								text];
		}
		else
		{
#warning 64BIT: Check formatting arguments
			[newtext appendFormat: @"**COPIED FROM: >>>%@ %d %@(%d)%@\n%@\n", 
								[db folderPathName:[thisMessage folderId]],
								[thisMessage messageId],  [thisMessage sender],
								[text length],
								[dateFormatter descriptionWithCalendarFormat: @"%d%b%y %H:%M"],  
								text];
		}
	}

	// Put string on the pasteboard for external drops.
	[pboard setString: newtext forType:NSStringPboardType];
	return YES;
}

-(void)readAcronyms
{
	// DJE modified here, 29 May 2013
	// The acronyms.lst file is using CP1252 encoding. Luckily, the 
	// BufferedFile class converts it to NSString internal encoding.

	BufferedFile * buffer = nil;
	NSString *fileName = [@"~/Library/Application Support/Vole/acronyms.lst" stringByExpandingTildeInPath];
	BOOL foundCommon = NO;
	BOOL endOfFile = NO;
	BOOL foundFile = NO;
	NSString * line;
	NSString * acronymsVersion = @"[ Acronyms list NOT INSTALLED ]";

	// Look for the acronyms file in ~/Library.
	if ([[NSFileManager defaultManager] isReadableFileAtPath: fileName]) {
		foundFile = YES;
		buffer = [[BufferedFile alloc] initWithPath: fileName];
	}
	acronymDictionary = [[NSMutableDictionary alloc] initWithCapacity: 20000];

	if(buffer) line = [buffer readLine:&endOfFile];
	while (foundFile && buffer && !endOfFile)
	{			
		if([line hasPrefix:@"[Acronyms.Lst Version"])
		{
			acronymsVersion = [ NSString stringWithFormat:@"%@]", line];
			line = [buffer readLine:&endOfFile];
			continue;
		}
		if ([line isEqualToString: @"[common]"])
			foundCommon = YES;

		if ([line hasPrefix:@"["] || !foundCommon)
		{
			line = [buffer readLine:&endOfFile];
			continue;
		}

		NSScanner * scanner = [NSScanner scannerWithString: line];
		NSString *acronym;
		NSString *expansion;

		
		[scanner scanUpToString:@"\t" intoString: &acronym];
		[scanner scanUpToString:@"" intoString: &expansion];
		if ( ! ((acronym == nil) || ( expansion == nil) ) ) 
			[acronymDictionary setObject: expansion forKey: acronym];
		
		line = [buffer readLine:&endOfFile];
	}
	// append our special acronyms at the end of the dictionary
	NSString * voleAcronyms[]={ @"Vole", @"VOLE", @"vole"}; // keys to lookup
	size_t i;
	NSString * version = [NSString stringWithFormat:@"%@ / %@",@"Small, cute, furry mammal / Vienna Off-Line Environment\n", acronymsVersion];  
#warning 64BIT: Inspect use of sizeof
	for (i = 0; i< sizeof(voleAcronyms) / sizeof(NSString *); i++){
		NSString * current = [ acronymDictionary valueForKey:voleAcronyms[i] ];
		if (current == nil) { // not in dict, so just use our version
			[acronymDictionary setObject:version forKey:voleAcronyms[i] ];
		}
		else { // already in dict, so append our special acronym to the current string.
			[ acronymDictionary setObject: [ NSString stringWithFormat:@"%@ / %@", current, version] forKey:voleAcronyms[i]  ];
		}
	}
	[buffer release];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
	[cixCredentials release];
	[personManager release];
	[browserController release];
	[priorityColour release];
	[originalIcon release];
	[extDateFormatter release];
	[searchFolder release];
	[rssFeed release];
	[importController release];
	[exportController release];
	[missingMessagesController release];
	[checkUpdates release];
	[preferenceController release];
	[activityViewer release];
	[tasksWindow release];
	[joinWindow release];
	[profileWindow release];
	[currentArrayOfMessages release];
	[backtrackArray release];
	[checkTimer release];
	[htmlDict release];
	[messageListFont release];
	[boldMessageListFont release];
	[db release];
	[super dealloc];
}
@end
