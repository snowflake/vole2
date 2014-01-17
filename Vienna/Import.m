//
//  Import.m
//  Vienna
//
//  Created by Steve on 5/27/05.
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

#import "Import.h"
#import "XMLParser.h"

// Private functions
@interface ImportController (Private)
	-(void)addRetrievedMessage:(NSArray *)messageDataArray;
	-(void)updateLastFolder:(NSNumber *)number;
	-(void)importScratchpad:(NSArray *)portArray;
	-(void)setImportFilename:(NSString *)name;
	-(void)initializeProgress:(NSNumber *)max;
	-(void)updateProgressText:(NSString *)progressInfo;
	-(void)updateProgressValue:(NSNumber *)progressValue;
@end

@implementation ImportController

/* init
 * Instance initialization
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		stopImportFlag = NO;
		importRunning = NO;
	}
	return self;
}

/* import
 * Kick off the import thread.
 */
-(void)import:(NSWindow *)window pathToFile:(NSString *)pathToFile database:(Database *)database
{
	// Save flags
	[self setImportFilename:pathToFile];
	db = database;
	stopImportFlag = NO;
	importRunning = YES;
	lastTopicId = -1;
	
	// Initialize UI
	if (!importSheet)
        // loadNibNamed:owner is deprecated in 10,8, but the replacement
        // is only available in 10.8 and later, so leave as is for the
        // moment (DJE)
		[NSBundle loadNibNamed:@"Import" owner:self];
	
	[stopButton setEnabled:YES];
	[progressInfo setStringValue:@""];
	[progressBar setDoubleValue:0];	
	[NSApp beginSheet:importSheet modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	
	// Start a transaction
	[db beginTransaction];
	
    // Start thread runnng
    [NSThread detachNewThreadSelector:@selector(importScratchpad:) toTarget:self withObject:nil];
}

/* endImport
 * Called when the import completes. We dismiss the sheet
 */
-(void)endImport
{
	// Commit the transaction
	[db commitTransaction];
	
	[NSApp endSheet:importSheet];
	[importSheet orderOut:self];
	importRunning = NO;
}

/* addRetrievedMessage
 * Called from the thread with a new message to be added to the database.
 */
-(void)addRetrievedMessage:(NSArray *)messageDataArray
{
// #warning 64BIT: Check formatting arguments
	NSAssert1([messageDataArray count] == 2, @"messageDataArray has wrong number of entries. Was %ld. Should be 2.", (long)[messageDataArray count]);
	VMessage * message = [messageDataArray objectAtIndex:0];
	NSString * messagePath = [messageDataArray objectAtIndex:1];
	
	[db addMessageToFolder:[db conferenceNodeID] path:messagePath message:message raw:YES wasNew:nil];
	[self updateLastFolder:[NSNumber numberWithLong:(long)[message folderId]]];
}

/* updateLastFolder
 * If the folder ID passed to this function is different from the folder ID when this function
 * was last called, we use this as a cue to tell the folder view to redraw itself so that changes
 * in the read/unread count are reflected in the folder name or style.
 */
-(void)updateLastFolder:(NSNumber *)number
{
// #warning 64BIT DJE
	NSInteger topicId = (NSInteger)[number intValue];
	if (topicId != lastTopicId && lastTopicId != -1)
	{
		[db flushFolder:lastTopicId];
		[db releaseMessages:lastTopicId];
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithLong:(long)lastTopicId]];
	}
	lastTopicId = topicId;
}

/* initializeProgress
 */
-(void)initializeProgress:(NSNumber *)max
{
	[progressBar setIndeterminate:NO];
	[progressBar setMinValue:0.0];
// #warning  64bit dje
	[progressBar setMaxValue:[max intValue]];
}

/* updateProgressText
 */
-(void)updateProgressText:(NSString *)progressText
{
	if (progressText != nil)
		[progressInfo setStringValue:progressText];
}

/* updateProgressValue
 */
-(void)updateProgressValue:(NSNumber *)progressValue
{
// #warning 64BIT dje
	[progressBar setDoubleValue:[progressValue doubleValue]];	
}

/* stopImport
 * Cancel the import thread and close the window.
 */
-(IBAction)stopImport:(id)sender
{
	if (importRunning)
	{
		stopImportFlag = YES;
		[self endImport];
	}
}

/* isImporting
 * Return YES if an import is running.
 */
-(BOOL)isImporting
{
	return importRunning;
}

/* setImportFilename
 */
-(void)setImportFilename:(NSString *)name
{
	[name retain];
	[importFilename release];
	importFilename = name;
}

/* importScratchpad
 * Reads a scratchpad and parses each message within it.
 */
-(void)importScratchpad:(NSArray *)portArray
{
	NSAutoreleasePool * pool;
	BufferedFile * buffer;
	
    pool = [[NSAutoreleasePool alloc] init];
	buffer = [[BufferedFile alloc] initWithPath:importFilename];
	[self performSelectorOnMainThread:@selector(initializeProgress:) withObject:[NSNumber numberWithLong:(long)[buffer fileSize]] waitUntilDone:YES];
	if (buffer != nil)
	{
		BOOL endOfFile;
		NSString * line = [buffer readLine:&endOfFile];
		
		while (!endOfFile && !stopImportFlag)
		{
	//		NSLog(@"raw line %@", line);  // DJE
//			BOOL read_flag = YES;
			BOOL read_flag = NO;  // dje changed from YES
			BOOL marked_flag = NO;
			BOOL ignore_flag = NO;
			BOOL author_flag = NO;
			BOOL keep_flag = NO;
			BOOL locked_flag = NO;
			
			NSString * messagePath;
			NSString * userName;
			NSString * messageBody;
			NSDate * messageDate;
			NSString * messageDateString;
			NSString * monthName;
			int messageNumber;
			int messageComment;
			int messageSize;
			int day, year;
			int hour, minute;
			BOOL hasMessage;
			
			// Initialize variables
			messageComment = 0;
			hasMessage = NO;
			monthName = nil;
			
			// Parse the !MF header if one is found and set flags. The
			// header format is the standard used by Semaphore and Ameol,
			// and possibly others. The format is !MF:<ch>*
			// where <ch> is one or more occurrences of the following:
			//   A - author message
			//   K - kept message
			//   I - ignored message
			//   U - unread message
			//   M - marked message
			//   L - locked message
			//
			if ([line hasPrefix:@"!MF:"])
			{
				NSUInteger index = 4;
				read_flag = YES; // DJE
				while (index < [line length])
					switch ([line characterAtIndex:index++])
					{
						case 'A': author_flag = YES; continue;
						case 'U': read_flag = NO; continue;
						case 'I': ignore_flag = YES; continue;
						case 'K': keep_flag = YES; continue;
						case 'M': marked_flag = YES; continue;
						case 'L': locked_flag = YES; continue;
					}
						
						// Get the next line
						line = [buffer readLine:&endOfFile];
				if (endOfFile)
					continue;
			}
			else if ([line hasPrefix:@"!S4:"])
			{
				NSUInteger index = 4;
				while (index < [line length])
					switch ([line characterAtIndex:index++])
					{
						case 'U': read_flag = ![line characterAtIndex:index++] == '1'; continue;
						case 'M': marked_flag = [line characterAtIndex:index++] == '1'; continue;
						case 'L': locked_flag = [line characterAtIndex:index++] == '1'; continue;
					}
			}
				
				// This is a mail message, so skip it. Happily the
				// size of the message appears in the header.
				if ([line hasPrefix:@"Memo #"])
				{
					NSScanner * scanner = [NSScanner scannerWithString:line];
					int messageNumber;
					int messageSize;
					
					[scanner scanString:@"Memo #" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageNumber];
					[scanner scanString:@"(" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageSize];
					messageBody = [buffer readTextOfSize:messageSize];
				}
				
				// This is a multi-line standard CIX header which has the same information
				// as a compact header, but spread over multiple lines.
				if ([line isEqualToString:@"=========="])
				{
					line = [buffer readLine:&endOfFile];
					if (endOfFile)
						continue;
					
					NSScanner * scanner = [NSScanner scannerWithString:line];
					[scanner scanUpToString:@" " intoString:&messagePath];
					[scanner scanString:@"#" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageNumber];
					[scanner scanString:@", from " intoString:nil];
					[scanner scanUpToString:@"," intoString:&userName];
					[scanner scanString:@", " intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageSize];
					[scanner scanString:@"chars, " intoString:nil];
					[scanner scanUpToString:@"" intoString:&messageDateString];
					
					// Convert the date and time into something we can work with
					messageDate = [NSCalendarDate dateWithString:messageDateString calendarFormat:@"%b %d %H:%M %y"];
					
					// Parse the next line which optionally specifies the comment
					line = [buffer readLine:&endOfFile];
					if (endOfFile)
						continue;
					
					scanner = [NSScanner scannerWithString:line];
					if ([scanner scanString:@"Comment to " intoString:nil])
					{
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
						[scanner scanInt:&messageComment];
						line = [buffer readLine:&endOfFile];
						if (endOfFile)
							continue;
					}
					if ([line isEqualToString:@"----------"])
					{
						if(messageSize < 2) messageSize++; // DJE added to compensate for decrement in next line
						messageBody = [buffer readTextOfSize:messageSize -1]; // DJE changed, because withdrawn messages are 1 byte shorter than usual
						hasMessage = YES;
					}
				}
				
				// Then parse a compact header to extract:
				//  - conference/topic name
				//  - size of message
				//  - username
				//  - comment number
				else if ([line hasPrefix:@">>>"])
				{
				//	NSLog(@"Line = %@", line); // DJE 
					NSScanner * scanner = [NSScanner scannerWithString:line]; 
					[scanner scanString:@">>>" intoString:nil];
					[scanner scanUpToString:@" " intoString:&messagePath];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageNumber];
					[scanner scanUpToString:@"(" intoString:&userName];
					[scanner scanString:@"(" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageSize];
					[scanner scanString:@")" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&day];
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&monthName];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&year];
//#warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&hour];
					[scanner scanString:@":" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&minute];
					[scanner scanString:@"c" intoString:nil];
// #warning 64BIT: scanInt: argument is pointer to int, not NSInteger; you can use scanInteger:
					[scanner scanInt:&messageComment];					
					
					// Convert the date and time into something we can work with
					// Handle bug in Parlance where some versions exported the year wrong.
					if (monthName != nil)
					{
						if (year >= 100)
							year -= 100;
// #warning 64BIT: Check formatting arguments
						messageDateString = [NSString stringWithFormat:@"%d%@%d %d:%d", day, monthName, year, hour, minute];
						messageDate = [NSCalendarDate dateWithString:messageDateString calendarFormat:@"%d%b%y %H:%M"];
						if (messageDate == nil)
							messageDate = [NSCalendarDate calendarDate];
						
						// Read the message body using the size as a clue.
						if (messageSize < 2) messageSize++; // DJE added, precomp messagesize
						messageBody = [buffer readTextOfSize:messageSize - 1]; // DJE, deal with ** Withdrawn by user ** messages which are one byte shorter
						hasMessage = YES;
					}
				}
				
				// Only if we have a message do we try to make sense of the
				// information we parsed.
				if (hasMessage)
				{
					// Ignore Mail, Logs or News folders
					if (!([messagePath hasPrefix:@"Mail/"] || [messagePath hasPrefix:@"News/"] || [messagePath hasPrefix:@"Logs/"]))
					{
						// Update progress
						NSString * progressString = [NSString stringWithFormat:@"Reading %@", messagePath];
						NSNumber * progressValue = [NSNumber numberWithLong:(long)[buffer readSoFar]];
						[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:progressString waitUntilDone:YES];
						[self performSelectorOnMainThread:@selector(updateProgressValue:) withObject:progressValue waitUntilDone:YES];
						
						// Now insert the message into the database
						VMessage * message = [[VMessage alloc] initWithInfo:messageNumber];
						[message setComment:messageComment];
						[message setSender:userName];
						NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc ] init ];  // DJE
						NSMutableString *mb = [NSMutableString stringWithCapacity: [messageBody length] +1];
						[mb appendString: messageBody];
						[ mb appendString: @"\n" ]; // DJE added to compensate for reading 1 byte short
				//		[message setText:messageBody];
						[message setText:mb ]; // DJE
						[ pool2 drain ]; // DJE
						[message setDateFromDate:messageDate];
						[message markRead:read_flag];
						[message markPriority:author_flag];
						[message markIgnored:ignore_flag];
						[message markFlagged:marked_flag];
						[self performSelectorOnMainThread:@selector(addRetrievedMessage:) withObject:[NSArray arrayWithObjects:message, messagePath, nil] waitUntilDone:YES];
						[message release];
					}
					else
					{
						NSString * progressString = [NSString stringWithFormat:@"Skipping %@", messagePath];
						NSNumber * progressValue = [NSNumber numberWithLong:(long)[buffer readSoFar]];
						[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:progressString waitUntilDone:YES];
						[self performSelectorOnMainThread:@selector(updateProgressValue:) withObject:progressValue waitUntilDone:YES];
					}
				}
				line = [buffer readLine:&endOfFile];
		}
			[buffer close];
	}
		[self performSelectorOnMainThread:@selector(updateLastFolder:) withObject:[NSNumber numberWithLong:(long)-1] waitUntilDone:YES];
		[buffer release];
		[pool release];
		[self performSelectorOnMainThread:@selector(stopImport:) withObject:nil waitUntilDone:NO];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[importFilename release];
	[super dealloc];
}
@end

@implementation AppController (Import)

/* importRSSSubscriptions
 * Import an OPML file which lists RSS feeds.
 */
-(IBAction)importRSSSubscriptions:(id)sender
{
	[self importOpenPanel:@selector(handleRSSSubscriptionsImport:)];
}

/* importCIXScratchpad
 * Handle the Import command to import a CIX/Ameol scratchpad.
 */
-(IBAction)importCIXScratchpad:(id)sender
{
	[self importOpenPanel:@selector(handleCIXScratchpadImport:)];
}

/* importOpenPanel
 * Shared code that displays the File Open panel for the import logic.
 */
-(void)importOpenPanel:(SEL)importHandler
{
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	NSArray * fileTypes = [NSArray arrayWithObjects:@"txt", @"text", @"opml", NSFileTypeForHFSTypeCode('TEXT'), nil];
	// The next method, beginSheetForDirectory, is deprecated, but the replacement
    // uses blocks, which are not available <10.6, so leave as is for the
    // moment. (DJE)
	[panel beginSheetForDirectory:nil
							 file:nil
							types:fileTypes
				   modalForWindow:mainWindow
					modalDelegate:self
				   didEndSelector:@selector(importOpenPanelDidEnd:returnCode:contextInfo:)
					  contextInfo:importHandler];
}

/* importOpenPanelDidEnd
 * Called when the user completes the Import open panel
 */
-(void)importOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[panel orderOut:self];
		[self performSelector:(SEL)contextInfo withObject:[panel filename]];
	}
}

/* handleCIXScratchpadImport
 * Import a CIX scratchpad from the specified file.
 */
-(void)handleCIXScratchpadImport:(NSString *)importFileName
{
	if (!importController)
		importController = [[ImportController alloc] init];
	[importController import:mainWindow pathToFile:importFileName database:db];
}

/* importSubscriptionGroup
 * Import one group of an OPML subscription tree.
 */
-(NSInteger)importSubscriptionGroup:(XMLParser *)tree
{
	NSInteger countImported = 0;
	NSInteger count = [tree countOfChildren];
	NSInteger index;
	
	for (index = 0; index < count; ++index)
	{
		XMLParser * outlineItem = [tree treeByIndex:index];
		NSDictionary * entry = [outlineItem attributesForTree];
		NSString * feedTitle = [entry objectForKey:@"title"];
		NSString * feedDescription = [entry objectForKey:@"description"];
		NSString * feedURL = [XMLParser processAttributes:[entry objectForKey:@"xmlUrl"]];

		if (feedURL == nil)
			countImported += [self importSubscriptionGroup:outlineItem];
		else
		{
			if ([db rssFolderFromURL:feedURL] == nil)
			{
				NSInteger folderId = [db addRSSFolder:feedTitle subscriptionURL:feedURL];
				if (feedDescription != nil)
					[db setFolderDescription:folderId newDescription:feedDescription];
				++countImported;
			}
		}
		countImported += [self importSubscriptionGroup:outlineItem];
	}
	return countImported;
}

/* handleRSSSubscriptionsImport
 * Import a list of RSS subscriptions.
 */
-(void)handleRSSSubscriptionsImport:(NSString *)importFileName
{
	NSData * data = [NSData dataWithContentsOfFile:importFileName];
	XMLParser * tree = [[XMLParser alloc] initWithData:data];
	XMLParser * bodyTree = [tree treeByPath:@"opml/body"];
	
	// Some OPML feeds organise exported subscriptions by groups. We can't yet handle those
	// so flatten the groups as we import.
	NSInteger countImported = [self importSubscriptionGroup:bodyTree];
	
	// Announce how many we successfully imported
// #warning 64BIT: Check formatting arguments
	NSString * successString = [NSString stringWithFormat:NSLocalizedString(@"%ld subscriptions successfully imported", nil), (long int)countImported];
	NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Import Title", nil), successString, NSLocalizedString(@"OK", nil), nil, nil);
	
	// Finished
	[tree release];
}
@end
