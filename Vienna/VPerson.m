//
//  VPerson.m
//  Vienna
//
//  Created by Steve on 11/23/04.
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

#import "VPerson.h"

@implementation VPerson

/* init
 * Initialise a VPerson object.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		// This means that the person's info isn't in the database.
		personId = -1;
	}
	return self;
}

/* setName
 * Set's the person's full name.
 */
-(void)setName:(NSString *)newName
{
	[newName retain];
	[name release];
	name = newName;
}

/* setShortName
 * Set's the person's short name.
 */
-(void)setShortName:(NSString *)newShortName
{
	[newShortName retain];
	[shortName release];
	shortName = newShortName;
}

/* setInfo
 * Sets a person's textual information (e.g. resume)
 */
-(void)setInfo:(NSString *)newInfo
{
	[newInfo retain];
	[info release];
	info = newInfo;
}

/* setParsedInfo
 * Sets a person's textual information (e.g. resume)
 */
-(void)setParsedInfo:(NSString *)newParsedInfo
{
	[newParsedInfo retain];
	[parsedInfo release];
	parsedInfo = newParsedInfo;
}

/* setPersonId
 * Sets the ID of the person.
 */
-(void)setPersonId:(NSInteger)newPersonId
{
	personId = newPersonId;
}

/* setPicture
 * Sets the person's picture.
 */
-(void)setPicture:(NSImage *)newPicture
{
	[newPicture retain];
	[picture release];
	picture = newPicture;
}

/* setEmailAddress
 * Sets the person's preferred e-mail address.
 */
-(void)setEmailAddress:(NSString *)newEmailAddress
{
	[newEmailAddress retain];
	[emailAddress release];
	emailAddress = newEmailAddress;
}

/* name
 * Returns the person's full name.
 */
-(NSString *)name
{
	return name;
}

/* shortName
 * Returns the person's short name.
 */
-(NSString *)shortName
{
	return shortName;
}

/* info
 * Returns the person's textual information.
 */
-(NSString *)info
{
	return info;
}

/* parsedInfo
 * Returns the person's textual information.
 */
-(NSString *)parsedInfo
{
	return parsedInfo;
}

/* personId
 * Returns the person Id
 */
-(NSInteger)personId
{
	return personId;
}

/* picture
 * Returns the person's picture.
 */
-(NSImage *)picture
{
	return picture;
}

/* emailAddress
 * Returns the person's preferred e-mail address.
 */
-(NSString *)emailAddress
{
	return emailAddress;
}

/* personCompare
 * Returns the result of comparing two items
 */
-(NSComparisonResult)personCompare:(VPerson *)otherObject
{
	return [name caseInsensitiveCompare:[otherObject name]];
}

/* description
 * Return a description of this object
 */
-(NSString *)description
{
	return [NSString stringWithFormat:@"Name=%@", shortName];
}

/* dealloc
 * Clean up at the end.
 */
-(void)dealloc
{
	[info release];
	[name release];
	[shortName release];
	[picture release];
	[super dealloc];
}
@end
