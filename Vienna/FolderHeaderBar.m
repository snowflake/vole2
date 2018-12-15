//
//  FolderHeaderBar.m
//  Vienna
//
//  Created by Steve on Fri May 13 2005.
//  Copyright (c) 2005 Steve Palmer. All rights reserved.
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

#import "FolderHeaderBar.h"


// Private functions
@interface FolderHeaderBar (Private)
	-(void)handleTintChange:(NSNotification *)nc;
@end

@implementation FolderHeaderBar

/* awakeFromNib
 * Do things that only make sense once the NIB is loaded.
 */
-(void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTintChange:) name:NSControlTintDidChangeNotification object:nil];
}

/* refreshForCurrentFolder
 * Update the displayed unread count for the current folder.
 */
-(void)refreshForCurrentFolder
{
	NSString * countString;
	
	// Note that [currentFolder messageCount] returns -1 if it hasn't cached
	// the messages for the folder yet. This is OK.
	if (folderCount <= 0)
// #warning 64BIT: Check formatting arguments
		countString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"No messages", nil) ];
	else
	{
// #warning 64BIT: Check formatting arguments
		countString = [NSString stringWithFormat:NSLocalizedString(@"Infobar Format", nil), (long)folderCount];
		if (currentFolder && [currentFolder unreadCount] && !IsSearchFolder(currentFolder))
// #warning 64BIT: Check formatting arguments
			countString = [countString stringByAppendingFormat:NSLocalizedString(@" (%ld unread)", nil), (long) [currentFolder unreadCount]];
	}
	[unreadCount setStringValue:countString];
}

/* setFolderCount
 */
-(void)setFolderCount:(NSInteger)newCount
{
	folderCount = newCount;
}

/* setCurrentFolder
 * Updates the current folder.
 */
-(void)setCurrentFolder:(Database *)db folderId:(NSInteger)folderId
{
	Folder * folder = [db folderFromID:folderId];
	NSMutableString * fullTitleString = [NSMutableString stringWithString:[db folderPathName:folderId]];
	if (IsFolderLocked(folder))
		[fullTitleString appendString:@" (Read Only)"];
#ifdef VOLE_ALPHA_STRING
    [fullTitleString appendString: VOLE_ALPHA_STRING];
#endif

	NSMutableAttributedString * newTitleString = [[NSMutableAttributedString alloc] initWithString:fullTitleString];
	if ([folder link])
	{
		NSRange attrRange = NSMakeRange(0, [newTitleString length]);
		[newTitleString addAttribute:NSLinkAttributeName value:[folder link] range:attrRange];
	}
	
	if ([folder description] && !([[folder description] isEqualToString:@""]))
	{
		[folderName setHidden:YES];
		[smallFolderName setHidden:NO];
		[folderDescription setHidden:NO];
		[smallFolderName setAllowsEditingTextAttributes:YES];
		[smallFolderName setAttributedStringValue:newTitleString];
		[folderDescription setStringValue:[folder description]];
	}
	else
	{
		[folderName setHidden:NO];
		[smallFolderName setHidden:YES];
		[folderDescription setHidden:YES];
		[folderName setAllowsEditingTextAttributes:YES];
		[folderName setAttributedStringValue:newTitleString];
	}

	currentFolder = folder;

	[self refreshForCurrentFolder];
}

/* handleTintChange
 * When the system control tint changes, we need to redraw our background.
 */
-(void)handleTintChange:(NSNotification *)nc
{
    (void)nc;
	[self setNeedsDisplay:YES];
}

/* drawRect
 * Paint the view background in the current system control tint.
 */
-(void)drawRect:(NSRect)rect
{
    (void)rect;
	NSRect brect = [self bounds];
	[[NSColor colorForControlTint:NSDefaultControlTint] set];
	NSRectFill(brect);
}

/* dealloc
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
