//
//  PersonManager.m
//  Vienna
//
//  Created by Steve on 12/17/04.
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

#import "PersonManager.h"
#import "PreferenceNames.h"
#import "XMLParser.h"
#import <AddressBook/AddressBook.h>

// Private functions
@interface PersonManager (Private)
	-(NSImage *)findMugshotFile:(NSString *)name;
	-(NSImage *)findMugshotInAB:(NSString *)name;
	-(NSString *)findFullNameInAB:(NSString *)name;
	-(void)parseResumeXFormat:(VPerson *)person;
	-(void)setMugshotInAB:(NSString *)name image:(NSData *)newImage;
	-(void)handleMugshotFolderChanged:(NSNotification *)nc;
@end

@implementation PersonManager

/* initWithDatabase
 * Initialises a new PersonManager object if none already exist and associates the
 * specified database with it.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [self init]) != nil)
	{
		db = newDb;
		mugshotsFolder = [[[[NSUserDefaults standardUserDefaults] stringForKey:MAPref_MugshotsFolder] stringByExpandingTildeInPath] retain];
	}
	return self;
}

/* setMugshotFolder
 * Sets the folder used to store mugshots.
 */
-(void)setMugshotFolder:(NSString *)newMugshotsFolder
{
	if (newMugshotsFolder == nil)
	{
		[mugshotsFolder release];
		mugshotsFolder = nil;
	}
	else
	{
		[newMugshotsFolder retain];
		[mugshotsFolder release];
		mugshotsFolder = [[newMugshotsFolder stringByExpandingTildeInPath] retain];
		[newMugshotsFolder release];
	}
}

/* updatePerson
 * Updates a person's info from the specified VPerson object.
 */
-(void)updatePerson:(VPerson *)person
{
	NSMutableString * resumeX = [NSMutableString stringWithFormat:@"<resume fullname=\"%@\" cixid=\"%@\">\n", [person name], [person shortName]];
	[resumeX appendFormat:@"<email>%@</email>\n", [person emailAddress]];
	[resumeX appendString:@"</resume>\n"];

	// Update the database
	NSString * resumeInfo = [NSString stringWithFormat:@"%@\n%@", [person parsedInfo], resumeX];
	[db updatePerson:[person shortName] data:resumeInfo];

	// Create a task to update this profile on the service. If there is
	// already a task to retrieve the profile then delete it as otherwise it
	// could overwrite the changes. Note that I've set the order code of the
	// PutResume lower than GetResume in order to guard against this so this
	// is somewhat a redundancy elimination measure.
	//
	VTask * existingTask = [db findTask:MA_TaskCode_GetResume wantedActionData:[person shortName]];
	if (existingTask)
		[db deleteTask:existingTask];
	[db addTask:MA_TaskCode_PutResume actionData:@"" folderName:@"" orderCode:MA_OrderCode_PutResume];
}

/* personFromPerson
 * Given the name of a person, this function returns a VPerson object that
 * contains as many details of that person as can be determined from the
 * people table or the address book.
 */
-(VPerson *)personFromPerson:(NSString *)personName
{
	VPerson * newPerson;

	// Get anything we know about this person from the database.
	newPerson = [[db retrievePerson:personName] retain];
	if (newPerson == nil)
		newPerson = [[VPerson alloc] init];
	[newPerson setShortName:personName];
	
	// See if the person's full name is in the address book
	// If not found then set it to the nickname instead.
	[newPerson setName:[self findFullNameInAB:personName]];
	if ([[newPerson name] isEqualToString:@""])
		[newPerson setName:personName];

	// Set a default e-mail address
	[newPerson setEmailAddress:[NSString stringWithFormat:@"%@@cix.co.uk", personName]];

	// Get the person's image. First try the address book then
	// try for a file in the mugshot directory.
	NSImage * image = [self findMugshotInAB:personName];
	if (!image)
	{
		image = [self findMugshotFile:personName];
		if (image && ![image isValid] && [personName length] > 8)
		{
			[image release];
			image = [self findMugshotFile:[personName substringToIndex:8]];
		}
	}
	if (image && ![image isValid])
	{
		[image release];
		image = nil;
	}
	[newPerson setPicture:image];
	[image release];

	// Parse the resumeX format. This will override our assumptions
	// so this should be one of the last things we do.
	[newPerson setParsedInfo:[newPerson info]];
	[self parseResumeXFormat:newPerson];
	
	// Now return what we have so far.
	return newPerson;
}

/* parseResumeXFormat
 * Locate and parse the resumeX format from the resume text.
 */
-(void)parseResumeXFormat:(VPerson *)person
{
	if ([person info] != nil)
	{
		NSScanner * scanner = [NSScanner scannerWithString:[person info]];
		NSString * preXMLBlock = @"";
		NSString * postXMLBlock = @"";
		NSString * resumeXMLText = nil;

		// Break out the resume section if there is one.
		[scanner scanUpToString:@"<resume " intoString:&preXMLBlock];
		[scanner scanUpToString:@"</resume>" intoString:&resumeXMLText];
		[scanner scanString:@"</resume>" intoString:nil];
		[scanner scanUpToString:@"" intoString:&postXMLBlock];
		if (resumeXMLText != nil)
		{
			// Append the </resume> end tag back onto the block (or use something
			// better than NSScanner for the parsing).
			NSMutableString * resumeText = [NSMutableString stringWithString:resumeXMLText];
			[resumeText appendString:@"</resume>"];
			// deprecated API here DJE
			//NSData * data = [NSData dataWithBytes:[resumeText cString] length:[resumeText length]];
			// replacement here
			NSData * data = [NSData 
							 dataWithBytes:[resumeText 
											cStringUsingEncoding:NSWindowsCP1252StringEncoding]
										   length:[resumeText length]];

			XMLParser * xmlTree = [[XMLParser alloc] initWithData:data];
			
			// Get the resume block
			if (xmlTree != nil)
			{
				XMLParser * xmlResume = [xmlTree treeByName:@"resume"];
				if (xmlResume != nil)
				{
					// Parse off the root block which is of the format:
					//
					//  <resume fullname="<fullname>" cixid="<cix nickname>">
					//
					// We're interested in the fullname part. The cixid should be known to us
					// unless we've screwed up somehow.
					//
					NSString * fullName = [[xmlResume attributesForTree] valueForKey:@"fullname"];
					if (fullName != nil)
						[person setName:fullName];

					// Now parse off the interesting parts
					NSString * emailAddress = [[xmlResume treeByName:@"email"] valueOfElement];
					if (emailAddress != nil)
						[person setEmailAddress:emailAddress];

					// We really ought to parse out the ResumeX block from the resume so it doesn't
					// show up in the profile window.
					if (preXMLBlock == nil) preXMLBlock = @"";
					if (postXMLBlock == nil) postXMLBlock = @"";
					[person setParsedInfo:[NSString stringWithFormat:@"%@%@", preXMLBlock, postXMLBlock]];
				}
			}
			[xmlTree release];
		}
	}
}

/* setPersonImage
 * Update the image for the specified person. Currently we save a copy as a file to
 * the mugshots folder but we also save a copy to the address book.
 */
-(void)setPersonImage:(NSString *)name image:(NSData *)newImage
{
	if (mugshotsFolder != nil)
	{
		NSString *mugFilename = [NSString stringWithFormat: @"%@/%@.tif", mugshotsFolder, name];
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm createFileAtPath:mugFilename contents:newImage attributes: nil];
	}
	[self setMugshotInAB:name image:newImage];
}

/* findMugshotFile
 * Look for a TIF, GIF, BMP or JPG file
 */
-(NSImage *)findMugshotFile:(NSString *)name
{
	if (mugshotsFolder == nil)
		return nil;
	NSMutableString *filename = [NSMutableString stringWithFormat: @"%@/%@.tif", mugshotsFolder, name];
	NSRange extension = NSMakeRange([filename length]-3, 3);
	
	// Look for files in BMP, GIF & JPG in that order
	NSImage *image = [[NSImage alloc] initByReferencingFile: filename];
	if (![image isValid]) 
	{
		[image release];
		[filename replaceCharactersInRange: extension withString: @"gif"];
		image = [[NSImage alloc] initByReferencingFile: filename];
	}		
	if (![image isValid]) 
	{
		[image release];
		[filename replaceCharactersInRange: extension withString: @"bmp"];
		image = [[NSImage alloc] initByReferencingFile: filename];
	}
	if (![image isValid]) 
	{
		[image release];
		[filename replaceCharactersInRange: extension withString: @"jpg"];
		image = [[NSImage alloc] initByReferencingFile: filename];
	}		
	return image;
}

/* findFullNameInAB
 * Look for the user in addressbook <user>@cix.co.uk
 * and return the person's full name if found or an empty string
 * otherwise.
 */
-(NSString *)findFullNameInAB:(NSString *)name
{
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	NSString * cixEmail = [NSString stringWithFormat: @"%@@cix.co.uk", name];
	ABSearchElement * se;
	NSArray * results;
	NSString * fullName = @"";

	se = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:cixEmail comparison:kABEqual];
	results = [ab recordsMatchingSearchElement: se];
	if ([results count] > 0)
	{
		// If we get multiple entries here (!) then just use the first.
		ABPerson *person = [results objectAtIndex: 0];
		if (person != nil)
		{
			NSString * firstName = [person valueForProperty:kABFirstNameProperty];
			NSString * lastName = [person valueForProperty:kABLastNameProperty];
			if ([firstName isEqualToString:@""])
				fullName = lastName;
			else if ([lastName isEqualToString:@""])
				fullName = firstName;
			else
				fullName = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
		}
	}
	return fullName;
}

/* findMugshotInAB
 * Look for the user in addressbook <user>@cix.co.uk
 * and return an image if found.
 */
-(NSImage *)findMugshotInAB:(NSString *)name
{
	ABAddressBook *ab = [ABAddressBook sharedAddressBook];
	NSString * cixEmail = [NSString stringWithFormat: @"%@@cix.co.uk", name];
	ABSearchElement *se;
	NSArray *results;
	NSImage *image = nil;
	
	se = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil
									  value:cixEmail comparison: kABEqual];
	results = [ab recordsMatchingSearchElement: se];
	if ([results count] > 0)
	{
		// If we get multiple entries here (!) then just use the first.
		ABPerson *person = [results objectAtIndex: 0];
		if (person && [person imageData])
		{
			image = [[NSImage alloc] initWithData: [person imageData]];
		}
	}
	return image;
}

/* setMugshotInAB
 * Look for the user in addressbook <user>@cix.co.uk
 * and update the image.
 */
-(void)setMugshotInAB:(NSString *)name image:(NSData *)newImage
{
	ABAddressBook *ab = [ABAddressBook sharedAddressBook];
	NSString * cixEmail = [NSString stringWithFormat: @"%@@cix.co.uk", name];
	ABSearchElement *se;
	NSArray *results;
	
	se = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil
									  value:cixEmail comparison: kABEqual];
	results = [ab recordsMatchingSearchElement: se];
	if ([results count] > 0)
	{
		// If we get multiple entries here (!) then just use the first.
		ABPerson *person = [results objectAtIndex: 0];
		if (person)
			[person setImageData:newImage];
	}
}

/* dealloc
 */
-(void)dealloc
{
	[mugshotsFolder release];
	[super dealloc];
}
@end
