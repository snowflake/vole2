//
//  VField.m
//  The Mac CIX OLR Project
//
//  Created by Steve on Mon Mar 22 2004.
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

#import "VField.h"

@implementation VField

/* init
 * Init an empty VField object.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		name = nil;
		visible = YES;
		width = 20;
		type = MA_FieldType_Integer;
		tag = -1;
	}
	return self;
}

-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

-(void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
}

-(void)setSqlField:(NSString *)newSqlField
{
	[newSqlField retain];
	[sqlField release];
	sqlField = newSqlField;
}

-(void)setType:(int)newType
{
	type = newType;
}

-(void)setTag:(int)newTag
{
	tag = newTag;
}

-(void)setVisible:(BOOL)flag
{
	visible = flag;
}

-(void)setWidth:(int)newWidth
{
	width = newWidth;
}

-(NSString *)name
{
	return name;
}

-(NSString *)title
{
	return title;
}

-(NSString *)sqlField
{
	return sqlField;
}

-(int)tag
{
	return tag;
}

-(int)type
{
	return type;
}

-(int)width
{
	return width;
}

-(BOOL)visible
{
	return visible;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"('%@', title='%@', sqlField='%@', tag=%d, width=%d, visible=%d)", name, title, sqlField, tag, width, visible];
}

-(void)dealloc
{
	[name release];
	[super dealloc];
}
@end
