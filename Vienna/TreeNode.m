//
//  TreeNode.m
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

#import "TreeNode.h"

@implementation TreeNode

/* init
 * Initialises a treenode.
 */
-(id)init:(TreeNode *)parent folder:(Folder *)theFolder canHaveChildren:(BOOL)childflag
{
	if ((self = [super init]) != nil)
	{
		NSInteger folderId = (theFolder ? [theFolder itemId] : MA_Root_NodeID);
		[self setFolder:theFolder];
		[self setParentNode:parent];
		[self setCanHaveChildren:childflag];
		[self setNodeId:folderId];
		if (parent != nil)
		{
			BOOL isOrdered = (folderId > MA_Conference_NodeID);
			[parent addChild:self ordered:isOrdered];
		}
		children = [[NSMutableArray array] retain];
	}
	return self;
}

/* addChild
 * Add the specified node to the parent's list of children
 */
-(void)addChild:(TreeNode *)child ordered:(BOOL)ordered
{
	NSAssert(canHaveChildren, @"Trying to add children to a node that cannot have children (canHaveChildren==NO)");
	TreeNode * previousChild = nil;
	TreeNode * forwardChild = nil;

	// If this is a search folder, put it before the Out Basket
	if (IsSearchFolder([child folder]))
	{
		NSEnumerator * enumerator = [children objectEnumerator];
		NSInteger insertIndex = 0;

		while ((forwardChild = [enumerator nextObject]) != nil)
		{
			if ([forwardChild nodeId] == MA_Outbox_NodeID)
				break;
			previousChild = forwardChild;
			++insertIndex;
		}
		[children insertObject:child atIndex:insertIndex];
	}
	
	// If ordering isn't important, bung the new child
	// at the end of the array.
	else if (!ordered)
	{
		if ([children count] > 0)
			previousChild = [children objectAtIndex:[children count] - 1];
		[children addObject:child];
	}
	else
	{
		NSString * ourChildName = [[child folder] name];
		NSUInteger insertIndex = 0;

		if ([children count] > 0)
			forwardChild = [children objectAtIndex:0];
		while (insertIndex < [children count])
		{
			TreeNode * theChild = [children objectAtIndex:insertIndex];
			NSString * theChildName = [[theChild folder] name];
			if ([theChildName caseInsensitiveCompare:ourChildName] == NSOrderedDescending)
				break;
			previousChild = theChild;
			++insertIndex;
		}
		[children insertObject:child atIndex:insertIndex];
	}
	if (previousChild)
	{
		forwardChild = [previousChild nextChild];
		[previousChild setNextChild:child];
	}
	[child setNextChild:forwardChild];
}

/* removeChild
 * Remove the specified child from the node list and any children
 * that it may have.
 */
-(void)removeChild:(TreeNode *)child
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * previousChild = nil;
	TreeNode * node;

	while ((node = [enumerator nextObject]) != nil)
	{
		if (node == child)
		{
			if (previousChild)
				[previousChild setNextChild:[node nextChild]];
			[children removeObject:node];
			[node removeChildren];
			break;
		}
		previousChild = node;
	}
}

/* removeChildren
 */
-(void)removeChildren
{
	[children removeAllObjects];
}

/* nodeFromID
 * Searches down from the current node to find the node that
 * has the given ID.
 */
-(TreeNode *)nodeFromID:(NSInteger)n
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * node;

	if ([self nodeId] == n)
		return self;
	while ((node = [enumerator nextObject]))
	{
		TreeNode * theNode;
		if ((theNode = [node nodeFromID:n]) != nil)
			return theNode;
	}
	return nil;
}

/* childByName
 * Returns the TreeNode for the specified named child
 */
-(TreeNode *)childByName:(NSString *)childName
{
	NSEnumerator * enumerator = [children objectEnumerator];
	TreeNode * node;
	
	while ((node = [enumerator nextObject]))
	{
		if ([childName isEqual:[node nodeName]])
			return node;
	}
	return nil;
}

/* setParentNode
 * Sets a treenode's parent
 */
-(void)setParentNode:(TreeNode *)parent
{
	parentNode = parent;
}

/* setNextChild
 */
-(void)setNextChild:(TreeNode *)child
{
	nextChild = child;
}

/* parentNode
 * Returns a tree node's parent.
 */
-(TreeNode *)parentNode
{
	return parentNode;
}

/* nextChild
 */
-(TreeNode *)nextChild
{
	return nextChild;
}

/* firstChild
 * Returns the first child node or nil if this node has no children
 */
-(TreeNode *)firstChild
{
	if ([children count] == 0)
		return nil;
	return [children objectAtIndex:0];
}

/* setNodeId
 * Sets a node's unique Id.
 */
-(void)setNodeId:(NSInteger)n
{
	nodeId = n;
}

/* nodeId
 * Returns the node's ID
 */
-(NSInteger)nodeId
{
	return nodeId;
}

/* setFolder
 * Sets a treenode's name
 */
-(void)setFolder:(Folder *)newFolder
{
	[newFolder retain];
	[folder release];
	folder = newFolder;
}

/* folder
 * Returns the folder associated with the node
 */
-(Folder *)folder
{
	return folder;
}

/* nodeName
 */
-(NSString *)nodeName
{
	return [folder name];
}

/* countOfChildren
 * Returns the number of direct child nodes of this node
 */
-(NSInteger)countOfChildren
{
	return [children count];
}

/* setCanHaveChildren
 * Sets the flag which specifies whether or not this node can have
 * children. This is not the same as actually adding children. The
 * outline view sets the expand symbol based on whether or not a
 * node item is ever expandable.
 */
-(void)setCanHaveChildren:(BOOL)childFlag
{
	canHaveChildren = childFlag;
}

/* canHaveChildren
 * Returns whether or not this node can have children.
 */
-(BOOL)canHaveChildren
{
	return canHaveChildren;
}

/* itemAtIndex
 * Returns the item from the child collection at the specified index
 */
-(TreeNode *)itemAtIndex:(NSInteger)index
{
	return (TreeNode *)[children objectAtIndex:index];
}

/* description
 * Returns a TreeNode description
 */
-(NSString *)description
{
// #warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"%@ (Parent=%ld, Sibling=%ld, # of children=%lu)",
            [folder name], (long)parentNode, (long)nextChild, (unsigned long)[children count]];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[children release];
	[folder release];
	[super dealloc];
}
@end
