//
//  Signatures.m
//  Vienna
//
//  Created by Steve on Mon May 03 2004.
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

#import "Signatures.h"
#import "PreferenceNames.h"

/* We maintain a singleton of all signatures for simplicity
 * even though the caller can create their own collection.
 */
static Signatures * defaultSignatures = nil;

@implementation Signatures

/* init
 * Create an empty signature dictionary.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		signatures = [[NSMutableDictionary dictionary] retain];
		[signatures addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:MAPref_Signatures]];
	}
	return self;
}

/* defaultSignatures
 * Return the default signatures singleton.
 */
+(Signatures *)defaultSignatures
{
	if (defaultSignatures == nil)
		defaultSignatures = [[Signatures alloc] init];
	return defaultSignatures;
}

/* signatureTitles
 * Return an array of all the signature titles.
 */
-(NSArray *)signatureTitles
{
	return [signatures allKeys];
}

/* signatureForTitle
 * Returns the signature identified by the specified title. The
 * title cannot be nil. If the title does not appear in the list
 * of signatures we know about, the return value is nil.
 */
-(NSString *)signatureForTitle:(NSString *)title
{
	return [signatures valueForKey:title];
}

/* addSignature
 * Adds a new signature (possibly replacing an existing signature
 * with the same title).
 */
-(void)addSignature:(NSString *)title withText:(NSString *)withText
{
	[signatures setObject:withText forKey:title];
	[[NSUserDefaults standardUserDefaults] setObject:signatures forKey:MAPref_Signatures];
}

/* removeSignature
 * Deletes the signature referenced by the specified title.
 */
-(void)removeSignature:(NSString *)title
{
	[signatures removeObjectForKey:title];
	[[NSUserDefaults standardUserDefaults] setObject:signatures forKey:MAPref_Signatures];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[signatures release];
	[super dealloc];
}
@end
