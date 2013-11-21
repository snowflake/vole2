//
//  FoldersTree.m
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

#import "FoldersTree.h"
#import "ImageAndTextCell.h"
#import "PreferenceNames.h"
#import "AppController.h"

// Private functions
@interface FoldersTree (Private)
	-(void)setFolderListFont;
	-(void)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node;
	-(void)handleDoubleClick:(id)sender;
	-(void)handleFolderAdded:(NSNotification *)nc;
	-(void)handleFolderUpdate:(NSNotification *)nc;
	-(void)handleFolderDeleted:(NSNotification *)nc;
	-(void)handleAutoCollapseChange:(NSNotification *)nc;
	-(void)handleFolderFontChange:(NSNotification *)note;
	-(NSString *)nodePathFromFolders:(TreeNode *)node;
	-(void)reloadFolderItem:(id)node reloadChildren:(BOOL)flag;
	-(void)expandToParent:(TreeNode *)node;
@end

@implementation FoldersTree

/* initWithFrame
 */
-(id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		// Root node is never displayed since we always display from
		// the second level down. It simply provides a convenient way
		// of containing the other nodes.
		rootNode = [[TreeNode alloc] init:nil folder:nil canHaveChildren:YES];
		lastExpandedNode = nil;
		isRefreshingFolder = NO;
		blockSelectionHandler = NO;

		// Register to be notified when folders are added or removed
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(handleFolderUpdate:) name:@"MA_Notify_FoldersUpdated" object:nil];
		[nc addObserver:self selector:@selector(handleFolderAdded:) name:@"MA_Notify_FolderAdded" object:nil];
		[nc addObserver:self selector:@selector(handleFolderDeleted:) name:@"MA_Notify_FolderDeleted" object:nil];
		[nc addObserver:self selector:@selector(outlineViewItemDidExpand:) name:NSOutlineViewItemDidExpandNotification object:(id)self];
		[nc addObserver:self selector:@selector(outlineViewItemDidCollapse:) name:NSOutlineViewItemDidCollapseNotification object:(id)self];
		[nc addObserver:self selector:@selector(outlineViewMenuInvoked:) name:@"MA_Notify_RightClickOnObject" object:nil];
		[nc addObserver:self selector:@selector(autoCollapseFolder:) name:@"MA_Notify_AutoCollapseFolder" object:nil];
		[nc addObserver:self selector:@selector(handleFolderFontChange:) name:@"MA_Notify_FolderFontChange" object:nil];
		[nc addObserver:self selector:@selector(handleAutoCollapseChange:) name:@"MA_Notify_AutoCollapseChange" object:nil];
	}
	return self;
}

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	NSTableColumn *	tableColumn;
	ImageAndTextCell * imageAndTextCell;

	// Our folders have images next to them.
    tableColumn = [outlineView tableColumnWithIdentifier:@"folderColumns"];
    imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
    [tableColumn setDataCell:imageAndTextCell];

	// Get a bold variant of the cell font for when we show folders with unread messages
	[self setFolderListFont];

	// Want tooltips
	[outlineView setEnableTooltips:YES];

	// Allow double-click a node to edit the node
	[outlineView setDoubleAction:@selector(handleDoubleClick:)];
	[outlineView setTarget:self];
	
	// Ensure the outline is populated
	[outlineView setAutoresizesOutlineColumn:YES];
	
	// Listen for drops from the messagelist
	[outlineView registerForDraggedTypes: [NSArray arrayWithObject:NSStringPboardType]];

	// Check if we do auto-collapse
	doAutoCollapse = [[NSUserDefaults standardUserDefaults] boolForKey:MAPref_AutoCollapseFolders];
	
	// Configure the popup menu button
	[popupMenu setMenu:folderMenu];
    [[popupMenu cell] setUsesItemFromMenu:NO];
    [[popupMenu cell] setBezelStyle:NSRegularSquareBezelStyle]; // DJE changed
    //[[popupMenu cell] setArrowPosition:NSPopUpArrowAtBottom];
    NSMenuItem * item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:@"" action:NULL keyEquivalent:@""];
    [item setImage:[NSImage imageNamed:@"Action.tiff"]];
    [item setOnStateImage:nil];
    [item setMixedStateImage:nil];
    [[popupMenu cell] setMenuItem:item];
    [item release];
    [popupMenu setPreferredEdge:NSMinXEdge];
    // menuRepresenatation is deprecated, so next line is commented out. (DJE)
    //  [[[popupMenu menu] menuRepresentation] setHorizontalEdgePadding:0.0];
}

/* handleFolderFontChange
 * Called when the user changes the folder font and/or size in the Preferences
 */
-(void)handleFolderFontChange:(NSNotification *)note
{
	[self setFolderListFont];
	[outlineView reloadData];
}

/* setFolderListFont
 * Creates or updates the fonts used by the message list.
 */
-(void)setFolderListFont
{
	int height;

	[cellFont release];
	[boldCellFont release];

	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_FolderFont];
	cellFont = [NSUnarchiver unarchiveObjectWithData:fontData];
	boldCellFont = [[NSFontManager sharedFontManager] convertWeight:YES ofFont:cellFont];
	// deprecated API was here DJE
	//	height = [boldCellFont defaultLineHeightForFont];
	NSLayoutManager *nsl = [[ NSLayoutManager alloc] init];
	height= (int) [ nsl defaultLineHeightForFont: boldCellFont];
	[ nsl release];
	[cellFont retain];  // DJE added
	[boldCellFont retain]; // DJE added

	[outlineView setRowHeight:height + 3];
}

/* outlineView
 * Returns the folders list's outline view.
 */
-(FolderView *)outlineView
{
	return outlineView;
}

/* reloadDatabase
 * Do the things to initialize the folder list from the database
 */
-(void)reloadDatabase
{
	[rootNode removeChildren];
	[self loadTree:[db arrayOfFolders:-1] rootNode:rootNode];
	[outlineView reloadData];
	[outlineView expandItem:[rootNode nodeFromID:[db conferenceNodeID]]];
	[outlineView expandItem:[rootNode nodeFromID:[db rssNodeID]]];
	lastExpandedNode = nil;
}

/* loadTree
 * Recursive routine that populates the folder list
 */
-(void)loadTree:(NSArray *)listOfFolders rootNode:(TreeNode *)node
{
	NSEnumerator * enumerator = [listOfFolders objectEnumerator];
	Folder * folder;

	while ((folder = [enumerator nextObject]) != nil)
	{
		int itemId = [folder itemId];
		NSArray * listOfSubFolders = [db arrayOfFolders:itemId];
		int count = [listOfSubFolders count];
		TreeNode * subNode;

		subNode = [[TreeNode alloc] init:node folder:folder canHaveChildren:(count > 0)];
		if (count)
			[self loadTree:listOfSubFolders rootNode:subNode];
	}	
}

/* folders
 * Returns an array that contains the specified folder and all
 * sub-folders.
 */
-(NSArray *)folders:(int)folderId
{
	NSMutableArray * array = [NSMutableArray array];
	TreeNode * node = [rootNode nodeFromID:folderId];

	[array addObject:[node folder]];
	node = [node firstChild];
	while (node != nil)
	{
		[array addObjectsFromArray:[self folders:[node nodeId]]];
		node = [node nextChild];
	}
	return array;
}

/* folderFromPath
 * Parses off a folder and returns the ID of the leaf node
 */
-(int)folderFromPath:(int)parentId path:(NSString *)path
{// deprecated API was here DJE
	const char * cString = [path cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	TreeNode * parentNode = [rootNode nodeFromID:parentId];
	NSRange range;

	// Parse off the folder path
	range.location = 0;
	range.length = 0;
	while (parentNode != nil)
	{
		if ((*cString == '\0' || *cString == '/') && range.length > 0)
		{
			parentNode = [parentNode childByName:[path substringWithRange:range]];
			range.location += range.length + 1;
			range.length = -1;
		}
		if (*cString == '\0')
			break;
		++range.length;
		++cString;
	}
	return parentNode ? [parentNode nodeId] : -1;
}

/* setDatabase
 * Set the database to be used by the folder list
 */
-(void)setDatabase:(Database *)newDb
{
	[newDb retain];
	[db release];
	db = newDb;
}

/* database
 * Returns the database associated with this folder tree.
 */
-(Database *)database
{
	return db;
}

/* updateFolder
 * Redraws a folder node
 */
-(void)updateFolder:(int)folderId recurseToParents:(BOOL)recurseToParents
{
	TreeNode * node = [rootNode nodeFromID:folderId];
	if (node != nil)
	{
		isRefreshingFolder = YES;
		[outlineView reloadItem:node reloadChildren:YES];
		if (recurseToParents)
		{
			while ([node parentNode] != rootNode)
			{
				node = [node parentNode];
				[outlineView reloadItem:node];
			}
		}
		isRefreshingFolder = NO;
	}
}

/* selectFolder
 * Move the selection to the specified folder.
 */
-(BOOL)selectFolder:(int)folderId
{
	TreeNode * node = [rootNode nodeFromID:folderId];
	if (!node)
		return NO;

	// Walk up to our parent
	[self expandToParent:node];
	int rowIndex = [outlineView rowForItem:node];
	if (rowIndex >= 0)
		// DJE changed here to use an NSIndexSet
	{	NSIndexSet *ind  =  [NSIndexSet indexSetWithIndex: rowIndex ];
		[outlineView selectRowIndexes: ind byExtendingSelection:NO];
		[outlineView scrollRowToVisible:rowIndex];
		
		// Now make the last folder of this parent visible, so the whole list of sub-folders
		// should be in view
		TreeNode *lastNode = node;
		while ((node = [node nextChild]) != nil)
			lastNode = node;
		[outlineView scrollRowToVisible: [outlineView rowForItem: lastNode]];
		[outlineView scrollRowToVisible:rowIndex];
		return YES;
	}
	return NO;
}

/* expandToParent
 * Expands the parent nodes all the way up to the root to ensure
 * that the node containing 'node' is visible.
 */
-(void)expandToParent:(TreeNode *)node
{
	if ([node parentNode])
	{
		[self expandToParent:[node parentNode]];
		[outlineView expandItem:[node parentNode]];
	}
}

/* nextFolderWithUnread
 * Finds the ID of the next folder after currentFolderId that has
 * unread messages.
 */
-(int)nextFolderWithUnread:(int)currentFolderId isPriority:(BOOL)priorityFlag
{
	TreeNode * thisNode = [rootNode nodeFromID:currentFolderId];
	TreeNode * node = thisNode;

	while (node != nil)
	{
		TreeNode * nextNode;
		TreeNode * parentNode = [node parentNode];
		nextNode = [node firstChild];
		if (nextNode == nil)
			nextNode = [node nextChild];
		while (nextNode == nil && parentNode != nil)
		{
			nextNode = [parentNode nextChild];
			parentNode = [parentNode parentNode];
		}
		if (nextNode == nil)
			nextNode = rootNode;

		// If we've gone full circle and not found
		// anything, we're out of unread messages
		if (nextNode == thisNode)
			return [thisNode nodeId];

		if (priorityFlag && [[nextNode folder] priorityUnreadCount])
			return [nextNode nodeId];

		if (!priorityFlag && [[nextNode folder] unreadCount])
			return [nextNode nodeId];

		node = nextNode;
	}
	return -1;
}

/* firstChildFolder
 * Returns the ID of the first child folder of this folder. If the
 * folder has no children, it returns itself. If the folderId is
 * invalid, it returns -1.
 */
-(int)firstChildFolder:(int)folderId
{
	TreeNode * thisNode = [rootNode nodeFromID:folderId];
	if (thisNode != nil)
	{
		TreeNode * childNode = [thisNode firstChild];
		return childNode ? [childNode nodeId] : [thisNode nodeId];
	}
	return -1;
}

/* isFolderExpanded
 * Returns whether the specified folder node is expanded.
 */
-(BOOL)isFolderExpanded:(TreeNode *)node
{
	return [outlineView isItemExpanded:node];
}

/* actualSelection
 * Returns the node ID of the selected row in the tree.
 */
-(int)actualSelection
{
	if ([outlineView numberOfSelectedRows] > 0)
	{
		TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
		return [node nodeId];
	}
	return -1;
}

/* outlineViewMenuInvoked
 */
-(void)outlineViewMenuInvoked:(NSNotification *)nc
{
	// Find the row under the cursor when the user clicked
	NSEvent * theEvent = [nc object];
	int row = [outlineView rowAtPoint:[outlineView convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (row >= 0)
    {
		// Select the row under the cursor if it isn't already selected
		if ([outlineView numberOfSelectedRows] <= 1)
			// DJE changed here to get rid of selectRow:byExtendingSelection log message 
			[outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] 
					 byExtendingSelection:NO];
    }
}

/* handleAutoCollapseChange
 * Respond when the state of the auto-collapse flag has changed.
 */
-(void)handleAutoCollapseChange:(NSNotification *)nc
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	BOOL newDoAutoCollapse = [defaults boolForKey:MAPref_AutoCollapseFolders];
	
	if (newDoAutoCollapse && !doAutoCollapse)
	{
		TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
		[outlineView collapseItem:[rootNode nodeFromID:[db conferenceNodeID]] collapseChildren:YES];
		[self expandToParent:node];
		[self selectFolder:[node nodeId]];
	}
	doAutoCollapse = newDoAutoCollapse;
}

/* handleDoubleClick
 * If the user double-clicks a node, send an edit notification.
 */
-(void)handleDoubleClick:(id)sender
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
	[nc postNotificationName:@"MA_Notify_EditFolder" object:node];
}

/* handleFolderDeleted
 * Called whenever a folder is removed from the database. We need
 * to delete the associated tree nodes then select the next node, or
 * the previous one if we were at the bottom of the list.
 */
-(void)handleFolderDeleted:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	TreeNode * thisNode = [rootNode nodeFromID:folderId];
	TreeNode * nextNode;

	// First find the next node we'll select
	if ([thisNode nextChild] != nil)
		nextNode = [thisNode nextChild];
	else
	{
		nextNode = [thisNode parentNode];
		if ([nextNode countOfChildren] > 1)
			nextNode = [nextNode itemAtIndex:[nextNode countOfChildren] - 2];
	}

	// Ask our parent to delete us
	TreeNode * ourParent = [thisNode parentNode];

	[ourParent removeChild:thisNode];
	[self reloadFolderItem:ourParent reloadChildren:YES];

	// Send the selection notification ourselves because if we're deleting at the end of
	// the folder list, the selection won't actually change and outlineViewSelectionDidChange
	// won't get tripped.
	blockSelectionHandler = YES;
	[self selectFolder:[nextNode nodeId]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_FolderSelectionChange" object:nextNode];
	blockSelectionHandler = NO;
}

/* handleFolderUpdate
 * Called whenever we need to redraw a specific folder, possibly because
 * the unread count changed.
 */
-(void)handleFolderUpdate:(NSNotification *)nc
{
	int folderId = [(NSNumber *)[nc object] intValue];
	[self updateFolder:folderId recurseToParents:YES];
}

/* handleFolderAdded
 * Called when a new folder is added to the database.
 */
-(void)handleFolderAdded:(NSNotification *)nc
{
	Folder * newFolder = (Folder *)[nc object];
	NSAssert(newFolder, @"Somehow got a NULL folder object here");

	int parentId = [newFolder parentId];
	TreeNode * node = (parentId == -1) ? rootNode : [rootNode nodeFromID:parentId];
	if (![node canHaveChildren])
		[node setCanHaveChildren:YES];
	[[TreeNode alloc] init:node folder:newFolder canHaveChildren:NO];
	[self reloadFolderItem:node reloadChildren:YES];
}

/* reloadFolderItem
 * Wrapper around reloadItem that sets isRefreshingFolder to YES.
 */
-(void)reloadFolderItem:(id)node reloadChildren:(BOOL)flag
{
	isRefreshingFolder = YES;
	if (node == rootNode)
		[outlineView reloadData];
	else
		[outlineView reloadItem:node reloadChildren:YES];
	isRefreshingFolder = NO;
}

/* outlineViewItemDidCollapse
 * Notification called when a node is collapsed. If the node is the conference
 * node, we clear lastExpandedNode to avoid a crash.
 */
-(void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	TreeNode * node = [[notification userInfo] objectForKey:@"NSObject"];
	if ([node nodeId] == [db conferenceNodeID])
		lastExpandedNode = nil;
}

/* outlineViewItemDidExpand
 * Handle auto-expand/collapse
 */
-(void)outlineViewItemDidExpand:(NSNotification *)notification
{
	TreeNode * node = [[notification userInfo] objectForKey:@"NSObject"];
	if (node != nil && [[node parentNode] nodeId] == [db conferenceNodeID] && !isRefreshingFolder)
	{
		if (lastExpandedNode != nil && lastExpandedNode != node && doAutoCollapse)
		{
			NSNotification * newNotification = [NSNotification notificationWithName:@"MA_Notify_AutoCollapseFolder" object:lastExpandedNode];
			[[NSNotificationQueue defaultQueue] enqueueNotification:newNotification postingStyle:NSPostASAP];
		}
		lastExpandedNode = node;
	}
}

/* autoCollapseFolder
 * Delayed notification to collapse a folder when another one is expanded.
 */
-(void)autoCollapseFolder:(NSNotification *)nc
{
	TreeNode * nodeToCollapse = (TreeNode *)[nc object];
	if (nodeToCollapse != nil)
		[outlineView collapseItem:nodeToCollapse];
}

/* isItemExpandable
 * Tell the outline view if the specified item can be expanded. The answer is
 * yes if we have children, no otherwise.
 */
-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node canHaveChildren];
}

/* numberOfChildrenOfItem
 * Returns the number of children belonging to the specified item
 */
-(int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node countOfChildren];
}

/* child
 * Returns the child at the specified offset of the item
 */
-(id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	return [node itemAtIndex:index];
}

/* tooltipForItem [dataSource]
 * For items that have counts, we show a tooltip that aggregates the counts.
 */
-(NSString *)outlineView:(FolderView *)outlineView tooltipForItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node != nil)
	{
		if ([[node folder] childUnreadCount])
			return [NSString stringWithFormat:@"%d unread messages", [[node folder] childUnreadCount]];
		if (([[node folder] permissions] == MA_ReadOnly_Folder) && [[node folder] unreadCount] > 0)
			return [NSString stringWithFormat:@"%d unread messages", [[node folder] unreadCount]];
	}
	return nil;
}

/* objectValueForTableColumn
 * Returns the actual string that is displayed in the cell.
 *
 * Folders to which the user can add messages show the folder name and the number of messages in the folder (e.g. Out Basket or Draft).
 * Folders with unread messages show the folder name and the number of unread messages in the folder.
 * For everything else, we just show the folder name.
 */
-(id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	TreeNode * node = (TreeNode *)item;
	if (node == nil)
		node = rootNode;
	if (([[node folder] permissions] == MA_ReadWrite_Folder) && [[node folder] messageCount] > 0)
		return ([NSString stringWithFormat:@"%@ (%d)", [node nodeName], [[node folder] messageCount]]);
	if (!IsSearchFolder([node folder]) && [[node folder] unreadCount])
		return ([NSString stringWithFormat:@"%@ (%d)", [node nodeName], [[node folder] unreadCount]]);
	return [node nodeName];
}

/* willDisplayCell
 * Hook before a cell is displayed to set the correct image for that cell.
 *
 * Folders to which the user can add messages which actually have messages are shown in bold face font (e.g. Out Basket or Draft).
 * Folders that have unread messages are shown in bold face font.
 * Everything else is shown in a non-bold font.
 */
-(void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item 
{    
    if ([[tableColumn identifier] isEqualToString:@"folderColumns"]) 
	{
		TreeNode * node = (TreeNode *)item;
		ImageAndTextCell * realCell = (ImageAndTextCell *)cell;

		if (([[node folder] permissions] == MA_ReadWrite_Folder) && [[node folder] messageCount] > 0)
			[realCell setFont:boldCellFont];
		else if (IsSearchFolder([node folder]))  // Because if the search results contain unread messages we don't want the search folder name to be bold.
			[realCell setFont:cellFont];
		else if ([[node folder] unreadCount] || [[node folder] childUnreadCount])
			[realCell setFont:boldCellFont];
		else
			[realCell setFont:cellFont];
		[realCell setImage:[db imageForFolder:[node folder]]];
	}
}

/* outlineViewSelectionDidChange
 * Called when the selection in the folder list has changed.
 */
-(void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	if (!blockSelectionHandler)
	{
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		TreeNode * node = [outlineView itemAtRow:[outlineView selectedRow]];
		[nc postNotificationName:@"MA_Notify_FolderSelectionChange" object:node];
	}
}

/* validateDrop
 * Caled when some text is being dragged over us, we have to decide whether
 * we want it or not
 */
-(NSDragOperation)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	TreeNode * node = item;

	// Prevent drops on to simple conference names or reserved folders
	if ([node canHaveChildren] || [node nodeId] <= MA_Max_Reserved_NodeID)
		return NSDragOperationNone;
	else
		return NSDragOperationCopy;
}

/* acceptDrop
 * Here's where we accept the drop operation. 
 * Note: this could actually be text dropped from (eg) TextEdit, not just internal messages.
 */
-(BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
	NSPasteboard *pboard = [info draggingPasteboard];
	TreeNode * node = item;
		
	// Get source message
	NSString * text = [pboard stringForType:NSStringPboardType];

	// Send message via outbox...copied code:
	VMessage *message = [[VMessage alloc] initWithInfo:-1];
	[message setNumber:-1];
	[message setFolderId:MA_Outbox_NodeID];
	[message setComment:0];
	[message setSender:[db folderPathName:[node nodeId]]];
	[message markRead:YES];
	[message setText:text];

	// Then pass it to db
	int messageNum = [db addMessage:MA_Outbox_NodeID message:message wasNew:nil];
	if (messageNum != -1)
		[message setNumber:messageNum];

	// Update the display
	[self updateFolder: MA_Outbox_NodeID recurseToParents:NO];
	return YES; 
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
	[rootNode release];
	[super dealloc];
}

@end
