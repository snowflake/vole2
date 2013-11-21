//
//  FoldersTree.h
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

#import <Cocoa/Cocoa.h>
#import "Vole.h"
#import "Database.h"
#import "TreeNode.h"
#import "FolderView.h"

@interface FoldersTree : NSView
{
	IBOutlet FolderView * outlineView;
	IBOutlet NSPopUpButton * popupMenu;
	IBOutlet NSMenu * folderMenu;
	TreeNode * rootNode;
	Database * db;
	NSFont * cellFont;
	NSFont * boldCellFont;
	TreeNode * lastExpandedNode;
	BOOL isRefreshingFolder;
	BOOL blockSelectionHandler;
	BOOL showingMenu;
	BOOL doAutoCollapse;
}

// Public functions
-(void)setDatabase:(Database *)db;
-(Database *)database;
-(void)reloadDatabase;
-(FolderView *)outlineView;
-(void)updateFolder:(int)folderId recurseToParents:(BOOL)recurseToParents;
-(BOOL)selectFolder:(int)folderId;
-(int)actualSelection;
-(BOOL)isFolderExpanded:(TreeNode *)node;
-(int)nextFolderWithUnread:(int)currentFolderId isPriority:(BOOL)priorityFlag;
-(int)firstChildFolder:(int)folderId;
-(NSArray *)folders:(int)folderId;
-(int)folderFromPath:(int)rootNode path:(NSString *)path;
@end
