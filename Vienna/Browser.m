//
//  Browser.m
//  Vienna
//
//  Created by Steve on Sat Jun 12 2004.
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

#import "Browser.h"

// Private functions
@interface Browser (Private)
	-(void)refreshBrowser:(id)sender;
	-(void)refreshTasksList:(NSInteger)category withFilter:(NSString *)filter;
	-(void)showSortDirection;
	-(void)setSortColumnIdentifier:(NSString *)str;
	-(void)sortForums;
@end

NSString * categoryNames[] = { @"All", @"Open", @"Closed" };
NSInteger categoryValues[] = { MA_All_Conferences, MA_Open_Conference, MA_Closed_Conference };
#define countOfCategories 3

NSInteger forumSortHandler(Forum * item1, Forum * item2, void * context);

@implementation Browser

/* initWithDatabase
 * Initialise the window.
 */
-(id)initWithDatabase:(Database *)theDb
{ //DJE re-arranged here 30/8/2014
    self=[super initWithWindowNibName:@"Browser"];
    if(self){
        db = theDb;
        currentArrayOfForums = nil;
        arrayOfCategories = [[NSMutableArray alloc] init];
        sortColumnIdentifier = @"name";
        sortDirection = 1;
        selectedCategory = -2;
    }
	return self;
}

/* windowDidLoad
 */
-(void)windowDidLoad
{
	// Create the toolbar.
    NSToolbar * toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MA_BrowserToolbar"] autorelease];
	
	// Now reload from the database
	currentCategory = MA_All_Conferences;
	[self refreshTasksList:currentCategory withFilter:nil];
	
    // Set the appropriate toolbar options. We are the delegate, customization is allowed,
	// changes made by the user are automatically saved and we start in icon+text mode.
    [toolbar setDelegate:(id)self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES]; 
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [browserWindow setToolbar:toolbar];
	[browserWindow setDelegate:(id)self];

	// Initialise the sort direction
	[self showSortDirection];

	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"browserWindow"];

	// Make the search control the next key view of the forum list
	[forumList setNextKeyView:searchView];
	[searchView setNextKeyView:browserList];
	
	// Extend the last column
	[forumList sizeLastColumnToFit];

	// Set the image for the status column
	[forumList setHeaderImage:@"status" imageName:@"forum_header.tiff"];

	// Set up targets for actions in the browser list
    [browserList setTarget:self];
    [browserList setAction:@selector(browserSingleClick:)];

	// Set the target for double-click actions
	[forumList setDoubleAction:@selector(joinFolder:)];
	[forumList setTarget:self];
	
	// Register a bunch of notifications
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];	
	[nc addObserver:self selector:@selector(handleForumUpdate:) name:@"MA_Notify_ForumsUpdated" object:nil];	
}

/* tableViewShouldDisplayCellToolTips
 * Called to ask whether the table view should display tooltips.
 */
-(BOOL)tableViewShouldDisplayCellToolTips:(NSTableView *)tableView
{
    (void)tableView;
	return YES;
}

/* toolTipForTableColumn
 * Return the tooltip for the specified row and column.
 */
-(NSString *)tableView:(NSTableView *)tableView toolTipForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    (void)tableView;
    (void)tableColumn;
	Forum * forum = [currentArrayOfForums objectAtIndex:rowIndex];
// #warning 64BIT: Check formatting arguments
	NSMutableString * tooltipString = [NSMutableString stringWithFormat:NSLocalizedString(@"Name: %@\n", nil), [forum name]];
	if ([[forum description] length] > 0)
// #warning 64BIT: Check formatting arguments
		[tooltipString appendFormat:NSLocalizedString(@"Description:%@\n", nil), [forum description]];
	if ([forum status] == MA_Empty_Conference)
		[tooltipString appendString:NSLocalizedString(@"This conference has no topics", nil)];
	if ([forum status] == MA_Closed_Conference)
		[tooltipString appendString:NSLocalizedString(@"This conference is closed", nil)];
	if ([forum status] == MA_Open_Conference)
	{
		NSString * outputFormat = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSShortDateFormatString"];
		NSCalendarDate * date = [[forum lastActiveDate] dateWithCalendarFormat:nil timeZone:nil];
// #warning 64BIT: Check formatting arguments
		[tooltipString appendFormat:NSLocalizedString(@"Last message posted on %@", nil), [date descriptionWithCalendarFormat:outputFormat]];
	}
	return tooltipString;
}

/* showSortDirection
 * Shows the current sort column and direction in the table.
 */
-(void)showSortDirection
{
	NSTableColumn * sortColumn = [forumList tableColumnWithIdentifier:sortColumnIdentifier];
	NSString * imageName = (sortDirection < 0) ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator";
	[forumList setHighlightedTableColumn:sortColumn];
	[forumList setIndicatorImage:[NSImage imageNamed:imageName] inTableColumn:sortColumn];
}

/* setSortColumnIdentifier
 */
-(void)setSortColumnIdentifier:(NSString *)str
{
	[str retain];
	[sortColumnIdentifier release];
	sortColumnIdentifier = str;
}

/* handleFolderUpdate
 * Respond to changes in a folder. This is really only the last active date so find the
 * specified folder in the list and refresh it.
 */
-(void)handleFolderUpdate:(NSNotification *)note
{
    (void)note;
//	int folderId = [(NSNumber *)[nc object] intValue];	
}

/* handleForumUpdate
 * The forum list has changed, so refresh our existing view.
 */
-(void)handleForumUpdate:(NSNotification *)note
{
    (void)note;
	[self refreshTasksList:currentCategory withFilter:nil];
}

/* numberOfRowsInColumn (delegate)
 * Returns the number of rows in the specified column of the browser.
 */
-(NSInteger)browser:(NSBrowser *)browser numberOfRowsInColumn:(NSInteger)column
{
    (void)browser;
	if (column == 0)
		return countOfCategories;
	if ((NSInteger)[arrayOfCategories count] >= column)
		return [[arrayOfCategories objectAtIndex:column - 1] count];
	return 0;
}

/* willDisplayCell (delegate)
 * Called by the browser to provide the value for the cell at the specified row and column.
 */
-(void)browser:(NSBrowser *)browser willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column
{
    (void)browser;
	if (column == 0)
		[cell setStringValue:categoryNames[row]];
	else
	{
		NSArray * categories = [arrayOfCategories objectAtIndex:column - 1];
		Category * category = [categories objectAtIndex:row];
		[cell setStringValue:[category name]];
	}
}

/* browserSingleClick
 * Handle single clicks in the browser.
 */
-(IBAction)browserSingleClick:(id)sender
{
    (void)sender;
	NSInteger column = [browserList selectedColumn];
	NSInteger categoryId = -2;

	if (column == 0)
	{
		NSInteger row = [browserList selectedRowInColumn:column];
		if (row >= 0 && row < countOfCategories && currentCategory != categoryValues[row])
		{
			currentCategory = categoryValues[row];
			selectedCategory = -2;
			[self refreshTasksList:currentCategory withFilter:nil];
		}
		categoryId = -1;
	}
	else
	{
		// Get the selected category
		NSInteger row = [browserList selectedRowInColumn:column];
		NSArray * categories = [arrayOfCategories objectAtIndex:column - 1];
		Category * category = [categories objectAtIndex:row];
		categoryId = [category categoryId];

		selectedCategory = categoryId;
		[self refreshTasksList:currentCategory withFilter:nil];
	}

	// Reload the next category column
	if (categoryId >= -1)
	{
		NSArray * array = [db arrayOfCategories:categoryId];
		while ((NSInteger)[arrayOfCategories count] > column)
			[arrayOfCategories removeObjectAtIndex:column];
		[arrayOfCategories insertObject:array atIndex:column];
		[browserList reloadColumn:column+1];
	}
}

/* sortForums
 * Re-orders the forums in currentArrayOfForums by the current sort order
 */
-(void)sortForums
{
	NSArray * sortedArrayOfForums;
	
	sortedArrayOfForums = [[currentArrayOfForums sortedArrayUsingFunction:forumSortHandler context:self] retain];
	NSAssert([sortedArrayOfForums count] == [currentArrayOfForums count], @"Lost messages from currentArrayOfForums during sort");
	[currentArrayOfForums release];
	currentArrayOfForums = [[NSArray arrayWithArray:sortedArrayOfForums] retain];
	[sortedArrayOfForums release];
	[forumList reloadData];
}

/* forumSortHandler
 * Compares two Forum objects.
 */
NSInteger forumSortHandler(Forum * item1, Forum * item2, void * context)
{
	Browser * app = (Browser *)context;
	if ([app->sortColumnIdentifier isEqualToString:@"name"])
		return [[item1 name] caseInsensitiveCompare:[item2 name]] * app->sortDirection;

	if ([app->sortColumnIdentifier isEqualToString:@"description"])
		return [[item1 description] caseInsensitiveCompare:[item2 description]] * app->sortDirection;
	
	if ([app->sortColumnIdentifier isEqualToString:@"date"])
		return [[item1 lastActiveDate] compare:[item2 lastActiveDate]] * app->sortDirection;

	if ([app->sortColumnIdentifier isEqualToString:@"status"])
		return [item1 status] < [item2 status] * app->sortDirection;

	return NSOrderedSame;
}	

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    (void)aTableView;
	return [currentArrayOfForums count];
}

/* refreshTable
 * Refreshes the table from the database.
 */
-(void)refreshTasksList:(NSInteger)category withFilter:(NSString *)filter
{
	[progressBar startAnimation:self];
	[statusString setStringValue:NSLocalizedString(@"Loading browser list...", nil)];

	[currentArrayOfForums release];
	if (filter == nil || [filter length] == 0)
	{
		currentArrayOfForums = [[db arrayOfForums:category inCategory:selectedCategory] retain];
		[(NSSearchField *)searchView setStringValue:@""];
	}
	else
	{
		NSEnumerator * enumerator = [[db arrayOfForums:category inCategory:selectedCategory] objectEnumerator];
		Forum * forum;
		NSMutableArray * newArrayOfForums = [[NSMutableArray alloc] initWithCapacity:400];
		while ((forum = [enumerator nextObject]) != nil)
		{
			if ([[forum name] rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound ||
				[[forum description] rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound)
			{
				[newArrayOfForums addObject:forum];
			}
		}
		
		currentArrayOfForums = [[NSArray arrayWithArray:newArrayOfForums] retain];
		[newArrayOfForums release];
	}
	
	[self sortForums];
	
// #warning 64BIT: Check formatting arguments
	NSString * status = [NSString stringWithFormat:NSLocalizedString(@"%ld items", nil),(long) [currentArrayOfForums count]];
	[statusString setStringValue:status];
	[progressBar stopAnimation:self];
}

/* didClickTableColumns
 * Handle the user click in the column header to sort by that column.
 */
-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	NSString * columnName = [tableColumn identifier];
	if ([sortColumnIdentifier isEqualToString:columnName])
		sortDirection *= -1;
	else
	{
		[forumList setIndicatorImage:nil inTableColumn:[tableView tableColumnWithIdentifier:sortColumnIdentifier]];
		[self setSortColumnIdentifier:columnName];
		sortDirection = 1;
	}

	// Do the sort
	[self showSortDirection];
	[self sortForums];
}

/* joinFolder
 * Handles the double-click action in a non-empty row.
 */
-(void)joinFolder:(id)sender
{
    (void)sender;
	NSInteger selectedRow = [forumList selectedRow];
	if (selectedRow >= 0 && selectedRow < (NSInteger)[currentArrayOfForums count])
	{
		Forum * forum = [currentArrayOfForums objectAtIndex:selectedRow];
		if (!joinWindow)
			joinWindow = [[Join alloc] initWithDatabase:db];
		[joinWindow joinCIXConference:[self window] initialConferenceName:[forum name]];
	}
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    (void)aTableView;
	NSString * identifier = [aTableColumn identifier];
	Forum * forum = [currentArrayOfForums objectAtIndex:rowIndex];
	
	// Show the icon representing the current state of the task
	if ([identifier isEqualToString:@"status"])
		switch ([forum status])
		{
			case MA_Empty_Conference:
			case MA_Open_Conference:
				return [NSImage imageNamed:@"openForum.tiff"];
				
			case MA_Closed_Conference:
				return [NSImage imageNamed:@"closedForum.tiff"];
				
			default:
				NSAssert(NO, @"Missed handling a status condition");
		}

	// Show the name
	if ([identifier isEqualToString:@"name"])
		return [forum name];
	
	// Show the description
	if ([identifier isEqualToString:@"description"])
		return [forum description];
	
	// Show the last active date unless the forum is closed
	if ([identifier isEqualToString:@"date"])
	{
		if ([forum status] == MA_Open_Conference)
		{
			NSString * outputFormat = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSShortDateFormatString"];
			NSCalendarDate * date = [[forum lastActiveDate] dateWithCalendarFormat:nil timeZone:nil];
			return [date descriptionWithCalendarFormat:outputFormat];
		}
		if ([forum status] == MA_Empty_Conference)
			return NSLocalizedString(@"Empty", nil);
		return NSLocalizedString(@"Closed", nil);
	}
	return @"";
}

/* printDocument
 * Print the table view.
 */
-(IBAction)printDocument:(id)sender
{
    (void)sender;
	NSPrintInfo * printInfo = [NSPrintInfo sharedPrintInfo];
	NSPrintOperation * printOp;
	
	printOp = [NSPrintOperation printOperationWithView:forumList printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}

/* searchBrowser
 * Executes a search using the search field on the toolbar.
 */
-(IBAction)searchBrowser:(id)sender
{
    NSString * searchString = [sender stringValue];
	[self refreshTasksList:currentCategory withFilter:searchString];
}

/* refreshBrowser
 * Refresh the selected top level node of the browser.
 */
-(void)refreshBrowser:(id)sender
{
    (void)sender;
	NSAssert(db != nil, @"Forgot to initialise db before calling refreshBrowser");
	[db addTask:MA_TaskCode_ConfList actionData:@"" folderName:@"" orderCode:MA_OrderCode_ConfList];
}

/* itemForItemIdentifier
 * This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching NSToolbarItem.
 * It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
 * going to be displayed in a customization palette.
 */
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    (void)toolbar; (void)flag;
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	if ([itemIdentifier isEqualToString:@"Refresh"])
	{
        [item setLabel:NSLocalizedString(@"Refresh", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"refresh.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(refreshBrowser:)];
	}
	if ([itemIdentifier isEqualToString:@"Join"])
	{
        [item setLabel:NSLocalizedString(@"Join", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"joinFolder.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(joinFolder:)];
	}
    else if ([itemIdentifier isEqualToString:@"SearchItem"])
	{
		NSRect fRect = [searchView frame];
		[item setLabel:NSLocalizedString(@"Search Browser", nil)];
		[item setPaletteLabel:[item label]];
		[item setView:searchView];
		[item setMinSize:fRect.size];
		[item setMaxSize:fRect.size];
		[item setTarget:self];
		[item setAction:@selector(searchBrowser:)];
    }
	return [item autorelease];
}

/* toolbarDefaultItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
 * set of toolbar items.  It can also be called by the customization palette to display the default toolbar.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    (void)toolbar;
    return [NSArray arrayWithObjects:NSToolbarPrintItemIdentifier,
									 @"Join",
									 NSToolbarFlexibleSpaceItemIdentifier,
									 @"SearchItem",
									 NSToolbarFlexibleSpaceItemIdentifier,
									 @"Refresh",
									 nil];
}

/* toolbarAllowedItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
 * toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    (void)toolbar;
    return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
									 NSToolbarSpaceItemIdentifier,
									 NSToolbarFlexibleSpaceItemIdentifier,
									 NSToolbarPrintItemIdentifier,
									 @"Refresh",
									 @"Join",
									 @"SearchItem",
									 nil];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[joinWindow release];
	[currentArrayOfForums release];
	[sortColumnIdentifier release];
	[super dealloc];
}
@end
