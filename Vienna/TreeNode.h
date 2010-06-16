//
//  TreeNode.h
//  Vienna
//
//  Created by Steve on Sat Jan 31 2004.
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

#import <Foundation/Foundation.h>
#import "Folder.h"

// Predefined node IDs. These must always be > 0
#define MA_Root_NodeID			1
#define MA_Outbox_NodeID		2
#define MA_Draft_NodeID			3
#define MA_Conference_NodeID	4
#define MA_Max_Reserved_NodeID	4	

// Folder permissions
//   MA_Empty_Folder = no messages can be stored in this folder
//   MA_ReadOnly_Folder = messages can be added or updated by the service to this folder but not modified by the user
//   MA_ReadWrite_Folder = messages can be added, deleted and updated in this folder by the user.
//   MA_Search_Folder = the messages are dynamically collected by a custom query
//
#define MA_Empty_Folder			0
#define MA_ReadOnly_Folder		1
#define MA_ReadWrite_Folder		2
#define MA_Search_Folder		3
#define MA_RSS_Folder			4
#define MA_FolderType_Mask		0x7FFF
#define MA_LockedFolder			0x8000

// Macro to simplify getting folder permissions
#define IsSearchFolder(f)		(([(f) permissions] & MA_FolderType_Mask) == MA_Search_Folder)
#define IsRSSFolder(f)			(([(f) permissions] & MA_FolderType_Mask) == MA_RSS_Folder)
#define IsFolderLocked(f)		([(f) permissions] & MA_LockedFolder)

@interface TreeNode : NSObject {
	TreeNode * parentNode;
	TreeNode * nextChild;
	NSMutableArray * children;
	Folder * folder;
	int nodeId;
	BOOL canHaveChildren;
}

-(id)init:(TreeNode *)parentNode folder:(Folder *)folder canHaveChildren:(BOOL)childflag;
-(void)setParentNode:(TreeNode *)parent;
-(void)setNextChild:(TreeNode *)child;
-(void)setFolder:(Folder *)newFolder;
-(TreeNode *)itemAtIndex:(int)index;
-(TreeNode *)parentNode;
-(TreeNode *)nextChild;
-(TreeNode *)firstChild;
-(void)addChild:(TreeNode *)child ordered:(BOOL)ordered;
-(void)removeChildren;
-(void)removeChild:(TreeNode *)child;
-(NSString *)nodeName;
-(TreeNode *)childByName:(NSString *)childName;
-(TreeNode *)nodeFromID:(int)n;
-(Folder *)folder;
-(int)nodeId;
-(void)setNodeId:(int)n;
-(int)countOfChildren;
-(void)setCanHaveChildren:(BOOL)childflag;
-(BOOL)canHaveChildren;
@end
