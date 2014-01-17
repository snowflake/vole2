//
//  Forum.m
//  Vienna
//
//  Created by Steve on Thu Jun 17 2004.
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

#import "Forum.h"

@implementation Forum

/* initWithName
 */
-(id)initWithName:(NSString *)newName
{
	if ((self = [super init]) != nil)
	{
		[self setName:newName];
	}
	return self;
}

/* categoryId
 */
-(NSInteger)categoryId
{
	return categoryId;
}

/* nodeId
 */
-(NSInteger)nodeId
{
	return nodeId;
}

/* status
 */
-(NSInteger)status
{
	return status;
}

/* lastActiveDate
 */
-(NSDate *)lastActiveDate
{
	return lastActiveDate;
}

/* folderId
 */
-(NSInteger)folderId
{
	return folderId;
}

/* name
 */
-(NSString *)name
{
	return name;
}

/* description
 */
-(NSString *)description
{
	return description;
}

/* setCategoryId
 */
-(void)setCategoryId:(NSInteger)newCategoryId
{
	categoryId = newCategoryId;
}

/* setNodeId
 */
-(void)setNodeId:(NSInteger)newNodeId
{
	nodeId = newNodeId;
}

/* setStatus
 */
-(void)setStatus:(NSInteger)newStatus
{
	status = newStatus;
}

/* setFolderId
 */
-(void)setFolderId:(NSInteger)newFolderId
{
	folderId = newFolderId;
}

/* setLastActiveDate
 */
-(void)setLastActiveDate:(NSDate *)newLastActiveDate
{
	[newLastActiveDate retain];
	[lastActiveDate release];
	lastActiveDate = newLastActiveDate;
}

/* setName
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* setDescription
 */
-(void)setDescription:(NSString *)newDescription
{
	[newDescription retain];
	[description release];
	description = newDescription;
}

/* dealloc
 */
-(void)dealloc
{
	[name release];
	[description release];
	[super dealloc];
}
@end
