//
//  Category.m
//  Vienna
//
//  Created by Steve on Sun Jun 20 2004.
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

#import "Category.h"

@implementation Category

/* initWithName
 * Create a new category and initialise it to the given name.
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
 * Return the category ID.
 */
-(int)categoryId
{
	return categoryId;
}

/* parentId
 * Return the category's parent ID.
 */
-(int)parentId
{
	return parentId;
}

/* name
 * Return the category name.
 */
-(NSString *)name
{
	return name;
}

/* setCategoryId
 * Set the category ID.
 */
-(void)setCategoryId:(int)newCategoryId
{
	categoryId = newCategoryId;
}

/* setParentId
 * Set the category's parent ID.
 */
-(void)setParentId:(int)newParentId
{
	parentId = newParentId;
}

/* setName
 * Set the category's name.
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* categoryCompare
 * Returns the result of comparing two items
 */
-(NSComparisonResult)categoryCompare:(Category *)otherObject
{
	return [name caseInsensitiveCompare:[otherObject name]];
}

/* dealloc
 * Clean up at the end.
 */
-(void)dealloc
{
	[name release];
	[super dealloc];
}
@end
