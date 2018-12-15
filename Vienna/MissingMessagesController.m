//
//  MissingMessagesController.m
//  Vienna
//
//  Created by Steve on Sun May 23 2004.
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

#import "MissingMessagesController.h"
#import "Folder.h"

// Private functions
@interface MissingMessagesController (Private)
	-(void)endScan;
	-(void)addFileMessageTask:(VTask *)newTask;
	-(void)updateProgressText:(NSString *)folderName;
	-(void)scanForMessages:(id)sender;
	-(void)enableOKButton:(NSTextField *)field;
@end

@implementation MissingMessagesController

/* init
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		arrayOfFolders = nil;
		messagesArray = nil;
	}
	return self;
}

/* getMissingMessages
 * Starts the UI to get missing messages in a specific folder.
 */
-(void)getMissingMessages:(NSWindow *)window arrayOfFolders:(NSArray *)folders database:(Database *)database
{
	if (!missingMessagesWindow)
		[NSBundle loadNibNamed:@"MissingMessages" owner:self];

	arrayOfFolders = folders;
	db = database;
	parentWindow = window;

	// Register our notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:messageNumber];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:skipBackCount];
		
	[NSApp beginSheet:missingMessagesWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

/* selectFillExisting
 * Called when the user selects the 'Fill existing range' option. Since the message number
 * field is not relevant for this, we disable it.
 */
-(IBAction)selectFillExisting:(id)sender
{
    (void)sender;
	[skipBackCount setEnabled:NO];
	[messageNumber setEnabled:NO];
	[okButton setEnabled:YES];
}

/* selectFillBackToSpecific
 * Called when the user selects the 'Fill back to specific message' option. Since the message number
 * field is relevant for this, we enable it.
 */
-(IBAction)selectFillBackToSpecific:(id)sender
{
    (void)sender;
	[skipBackCount setEnabled:NO];
	[messageNumber setEnabled:YES];
	[self enableOKButton:messageNumber];
}

/* selectSkipBack
 * Called when the user selects the 'Skip back to' option. Enable the skip back count field and disable
 * the message number field.
 */
-(IBAction)selectSkipBack:(id)sender
{
    (void)sender;
	[skipBackCount setEnabled:YES];
	[messageNumber setEnabled:NO];
	[self enableOKButton:skipBackCount];
}

/* enableOKButton
 * Enable or disable the OK button depending on whether or not there is a non-blank
 * string in the input field.
 */
-(void)enableOKButton:(NSTextField *)field
{
	NSString * fieldValue = [field stringValue];
	fieldValue = [fieldValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[okButton setEnabled:![fieldValue isEqualToString:@""]];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of an input field is changed.
 * We disable the OK button if the input field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	[self enableOKButton:[aNotification object]];
}

/* doOK
 * Handle the OK button being clicked.
 */
-(IBAction)doOK:(id)sender
{
	// Set flags
	stopScanFlag = NO;
	scanRunning = YES;
	countOfTasks = 0;
	countOfMessages = 0;
	countOfFolders = 0;
	skipBackValue = 0;
// #warning 64BIT: Inspect use of MAX/MIN constant; consider one of LONG_MAX/LONG_MIN/ULONG_MAX/DBL_MAX/DBL_MIN, or better yet, NSIntegerMax/Min, NSUIntegerMax, CGFLOAT_MAX/MIN
	requiredFirstMessage = NSUIntegerMax;   // was UINT_MAX;

	if ([fillBackToSpecific state] == NSOnState)
// #warning 64BIT dje check this  ( using intValue instead of integerValue)
		requiredFirstMessage = [messageNumber intValue];

	if ([skipBack state] == NSOnState)
// #warning 64Bit DJE check this ( using intValue instead of integerValue)		
		skipBackValue = [skipBackCount intValue];
	
	// Dismiss the options sheet.
	[missingMessagesWindow orderOut:sender];
	[NSApp endSheet:missingMessagesWindow];

	// Open the progress window
	if (!missingMessagesProgressWindow)
		[NSBundle loadNibNamed:@"MissingMessagesProgress" owner:self];

	// Remember that we reuse sheets without reloading them so we need to
	// re-initialise to remove the state from the last run.
	[stopButton setEnabled:YES];
	[progressInfo setStringValue:@""];

	[progressBar setDoubleValue:0];		
	[progressBar setIndeterminate:NO];
	[progressBar setMinValue:0.0];
	[progressBar setMaxValue:[arrayOfFolders count]];
	
	[NSApp beginSheet:missingMessagesProgressWindow modalForWindow:parentWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
	
    // Start thread runnng
    [NSThread detachNewThreadSelector:@selector(scanForMessages:) toTarget:self withObject:nil];
}

/* endScan
 * Called when the scan completes. We dismiss the sheet
 */
-(void)endScan
{
	[NSApp endSheet:missingMessagesProgressWindow];
	[missingMessagesProgressWindow orderOut:self];
	scanRunning = NO;
}

/* addFileMessageTask
 * Called from the thread to add a new task object to the database.
 */
-(void)addFileMessageTask:(VTask *)newTask
{
	[db addTask:newTask];
	++countOfTasks;

	// This is a good time to update the progress text
	[self updateProgressText:[newTask folderName]];
}

/* updateProgressText
 * Update the progress information string.
 */
-(void)updateProgressText:(NSString *)folderName
{
// #warning 64BIT: Check formatting arguments
	NSString * text = [NSString stringWithFormat:@"%@ (%ld messages in %ld tasks)", folderName, (long)countOfMessages, (long)countOfTasks];
	[progressInfo setStringValue:text];
	[progressBar setDoubleValue:countOfFolders];	
}

/* getMessagesForFolder
 * Call the database to retrieve the messages for the specified folder.
 */
-(void)getMessagesForFolder:(Folder *)folder
{
	messagesArray = [db arrayOfMessagesNumbers:[folder itemId]];
}

/* isScanning
 * Returns whether a missing message scan is running.
 */
-(BOOL)isScanning
{
	return scanRunning;
}

/* stopScan
 * Cancel the scan. Called when the user hits the Stop button.
 */
-(IBAction)stopScan:(id)sender
{
    (void)sender;
	if (scanRunning)
	{
		stopScanFlag = YES;
		[self endScan];
	}
}

/* scanForMessages
 * This is the main thread that scans the database.
 */
-(void)scanForMessages:(id)sender
{
    (void)sender;
	Folder * folder;
	VTask * task;
	
    @autoreleasepool {
		task = [[VTask alloc] init];

		NSEnumerator * objectEnumerator = [arrayOfFolders objectEnumerator];
		while ((folder = [objectEnumerator nextObject]) && !stopScanFlag)
		{
			// Note: folderPathName is one of the "safe" db functions in that it doesn't talk to
			// the database.
			NSString * folderName = [db folderPathName:[folder itemId]];

			// Update the progress text as we hit each folder
			++countOfFolders;
			[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:folderName waitUntilDone:YES];

			// Skip back actions are very easy
			if (skipBackValue)
			{
				VTask * task = [[VTask alloc] init];
				[task setActionCode:MA_TaskCode_SkipBack];
				[task setOrderCode:MA_OrderCode_SkipBack];
// #warning 64BIT: Check formatting arguments
				[task setActionData:[NSString stringWithFormat:@"%ld", (long)skipBackValue]];
				[task setFolderName:folderName];
				[self performSelectorOnMainThread:@selector(addFileMessageTask:) withObject:task waitUntilDone:YES];
			}
			else
			{
				// Call the main thread to reload the messagesArray. All db access MUST be on the main thread
				[self performSelectorOnMainThread:@selector(getMessagesForFolder:) withObject:folder waitUntilDone:YES];
				if ([messagesArray count] > 0)
				{
					NSUInteger firstMessageNumber;
					NSUInteger nextMessageNumber;
					NSUInteger count;
					
// #warning 64BIT: Inspect use of MAX/MIN constant; consider one of LONG_MAX/LONG_MIN/ULONG_MAX/DBL_MAX/DBL_MIN, or better yet, NSIntegerMax/Min, NSUIntegerMax, CGFLOAT_MAX/MIN
					if (requiredFirstMessage == NSUIntegerMax)
// #warning 64BIT DJE using intValue instead of integerValue
						firstMessageNumber = (NSUInteger)[[messagesArray objectAtIndex:0] intValue];
					else
						firstMessageNumber = requiredFirstMessage;
					nextMessageNumber = firstMessageNumber;
					
					for (count = 0; count < [messagesArray count] && !stopScanFlag; ++count)
					{
// #warning 64BIT DJE using intValue instead of integerValue
						NSUInteger thisMessageNumber = (NSUInteger)[[messagesArray objectAtIndex:count] intValue];
						if (thisMessageNumber != nextMessageNumber && thisMessageNumber > firstMessageNumber)
						{
							NSMutableString * rangeString;
							
// #warning 64BIT: Check formatting arguments
							rangeString = [NSMutableString stringWithFormat:@"%ld", (long)nextMessageNumber];
							if (nextMessageNumber < thisMessageNumber - 1)
// #warning 64BIT: Check formatting arguments
								[rangeString appendFormat:@"-%ld",(long) thisMessageNumber - 1];

							// Keep a running total of the number of missing messages
							countOfMessages += thisMessageNumber - nextMessageNumber;

							// Call the main thread to actually add the task to the database. We can't do it
							// here or we'll bugger up the database.
							VTask * task = [[VTask alloc] init];
							[task setActionCode:MA_TaskCode_FileMessages];
							[task setOrderCode:MA_OrderCode_FileMessages];
							[task setActionData:rangeString];
							[task setFolderName:folderName];
							[self performSelectorOnMainThread:@selector(addFileMessageTask:) withObject:task waitUntilDone:YES];
						}
						nextMessageNumber = thisMessageNumber + 1;
					}
				}
			}
		}
	}
	[self performSelectorOnMainThread:@selector(stopScan:) withObject:nil waitUntilDone:NO];
}

/* doCancel
 * Handle the Cancel button being clicked.
 */
-(IBAction)doCancel:(id)sender
{
	[missingMessagesWindow orderOut:sender];
	[NSApp endSheet:missingMessagesWindow];
}

/* dealloc
 */
@end
