//
//  Export.m
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

#import "Export.h"
#import "FoldersTree.h"
#import "XMLParser.h"
#import "StringExtensions.h"

// Private functions
@interface ExportController (Private)
	-(void)endExport;
	-(void)exportFolders:(NSArray *)arrayOfFolders;
	-(void)exportFolder:(Folder *)folder toFileHandle:(NSFileHandle *)fileHandle;
	-(void)updateProgressText:(NSString *)progressText;
@end

@implementation ExportController

/* export
 * Export an array of folders to the CIX scratchpad format.
 */
-(void)export:(NSWindow *)window pathToFile:(NSString *)pathToFile database:(Database *)database arrayOfFolders:(NSArray *)arrayOfFolders
{
	// Save parameters
	db = database;
	stopExportFlag = NO;
	exportRunning = YES;
	messageText = nil;
	messages = nil;
	
	// Initialize UI
	if (!exportSheet)
		[NSBundle loadNibNamed:@"Export" owner:self];
	
	[stopButton setEnabled:YES];
	[progressInfo setStringValue:@""];
	[progressBar setDoubleValue:0];
	
	// Make sure we can actually create the file. I suspect there's some race condition here caused
	// by Cocoa's bizarre separation of creating the file and opening the file for writing. I've been
	// unable to figure out how to atomically create a file and get a handle. Maybe future
	// generations of nerds will have some luck but right now, I give up. The ways of Apple are
	// mysterious.
	if (![[NSFileManager defaultManager] createFileAtPath:pathToFile contents:nil attributes:nil])
	{
		NSBeginCriticalAlertSheet(NSLocalizedString(@"Cannot open export file message", nil),
								  NSLocalizedString(@"OK", nil),
								  nil,
								  nil, [NSApp mainWindow], self,
								  nil, nil, nil,
								  NSLocalizedString(@"Cannot open export file message text", nil));
	}
	else
	{
		// Make a copy of the export filename since the thread actually opens the file
		[pathToFile retain];
		[exportFilename release];
		exportFilename = pathToFile;
		
		// Set the progress range to be the number of folders we are exporting. We won't know how
		// many messages in each folder until we process them.
		[progressBar setIndeterminate:NO];
		[progressBar setMinValue:0.0];
		[progressBar setMaxValue:[arrayOfFolders count]];
		
		[NSApp beginSheet:exportSheet modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
		
		// Start thread runnng
		[NSThread detachNewThreadSelector:@selector(exportFolders:) toTarget:self withObject:arrayOfFolders];
	}
}

/* endExport
 * Called when the export completes. We dismiss the sheet
 */
-(void)endExport
{
	[NSApp endSheet:exportSheet];
	[exportSheet orderOut:self];
	exportRunning = NO;
}

/* isExporting
 * Return YES if an export is running.
 */
-(BOOL)isExporting
{
	return exportRunning;
}

/* stopExport
 * Cancel the export thread and close the window.
 */
-(IBAction)stopExport:(id)sender
{
	if (exportRunning)
	{
		stopExportFlag = YES;
		[self endExport];
	}
}

/* loadMessagesArray
 */
-(void)loadMessagesArray:(Folder *)folder
{
	BOOL isSorted;
	
	NSString * folderPath = [db folderPathName:[folder itemId]];
	NSString * progressText = [NSString stringWithFormat:NSLocalizedString(@"Retrieving messages from %@", nil), folderPath];
	[self updateProgressText:progressText];
	
	[messages release];
	messages = [[db arrayOfMessages:[folder itemId] filterString:@"" withoutIgnored:NO sorted:&isSorted] retain];
}

/* loadMessageText
 */
-(void)loadMessageText:(VMessage *)message
{
	[messageText release];
	messageText = [[db messageText:[message folderId] messageId:[message messageId]] retain];
}

/* updateProgressText
 */
-(void)updateProgressText:(NSString *)progressText
{
	if (progressText != nil)
	{
		[progressInfo setStringValue:progressText];
		[progressBar setDoubleValue:countOfFolders];	
	}
}

/* exportFolders
 * This is the export function running on a separate thread.
 */
-(void)exportFolders:(NSArray *)arrayOfFolders
{
	NSAutoreleasePool * pool;
    pool = [[NSAutoreleasePool alloc] init];
	
	NSString * progressText = [NSString stringWithFormat:NSLocalizedString(@"Opening '%@'", nil), exportFilename];
	[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:progressText waitUntilDone:YES];
	
	NSFileHandle * fileHandle = [NSFileHandle fileHandleForWritingAtPath:exportFilename];
	NSEnumerator * enumerator = [arrayOfFolders objectEnumerator];
	Folder * folder;
	
	countOfFolders = 0;
	lastFolderId = -1;
	while ((folder = [enumerator nextObject]) && !stopExportFlag)
	{
		++countOfFolders;
		[self exportFolder:folder toFileHandle:fileHandle];
	}
	
	[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:NSLocalizedString(@"Completed", nil) waitUntilDone:YES];
	
	[fileHandle closeFile];
	[pool release];
	[self performSelectorOnMainThread:@selector(stopExport:) withObject:nil waitUntilDone:NO];
}

/* exportFolder
 * Export the messages in the specified folder, then export messages in any
 * child folders.
 */
-(void)exportFolder:(Folder *)folder toFileHandle:(NSFileHandle *)fileHandle
{
	// Call the main thread to load the messages array from the db.
	[self performSelectorOnMainThread:@selector(loadMessagesArray:) withObject:folder waitUntilDone:YES];
	
	NSEnumerator * enumerator = [messages objectEnumerator];
	VMessage * theMessage;
	
	while ((theMessage = [enumerator nextObject]) && !stopExportFlag)
	{
		NSString * folderPath = [db folderPathName:[theMessage folderId]];
		NSCalendarDate * theDate = [[theMessage date] dateWithCalendarFormat:nil timeZone:nil];
		NSString * dateString = [theDate descriptionWithCalendarFormat:@"%d%b%y %H:%M"];
		NSString * commentString = [theMessage comment] > 0 ? [NSString stringWithFormat:@" c%d", [theMessage comment]] : @"";
		
		// Only report progress on change of folder
		if ([theMessage folderId] != lastFolderId)
		{
			NSString * progressText = [NSString stringWithFormat:NSLocalizedString(@"Exporting from %@", nil), folderPath];
			[self performSelectorOnMainThread:@selector(updateProgressText:) withObject:progressText waitUntilDone:YES];
			lastFolderId = [theMessage folderId];
		}
		
		// Call the main thread to retrieve the text of a specific message
		[self performSelectorOnMainThread:@selector(loadMessageText:) withObject:theMessage waitUntilDone:YES];
		int size = [messageText length];
		
		NSMutableString * msgStatus = [NSMutableString stringWithString:@"!MF:"];
		if ([theMessage isPriority])
			[msgStatus appendString:@"A"];
		if (![theMessage isRead])
			[msgStatus appendString:@"U"];
		if ([theMessage isIgnored])
			[msgStatus appendString:@"I"];
		if ([theMessage isFlagged])
			[msgStatus appendString:@"M"];
		
		NSString * msgText = [NSString stringWithFormat:@"%@\n>>>%@ %d %@(%d)%@%@\n%@\n",
			msgStatus,
			folderPath,
			[theMessage messageId],
			[theMessage sender],
			size,
			dateString,
			commentString,
			messageText];
		NSData * msgData = [NSData dataWithBytes:[msgText cStringUsingEncoding:NSISOLatin1StringEncoding] length:[msgText length]];
		[fileHandle writeData:msgData];
	}
	
	// This line is essential if we're not to end up eating all the memory on
	// the system!
	[folder clearMessages];
	[messages release];
	messages = nil;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[messages release];
	[messageText release];
	[exportFilename release];
	[super dealloc];
}
@end

@implementation AppController (Export)

/* exportRSSSubscriptions
 * Export the list of RSS subscriptions as an OPML file.
 */
-(IBAction)exportRSSSubscriptions:(id)sender
{
	[self exportSavePanel:@selector(handleRSSSubscriptionsExport:)];
}

/* exportCIXScratchpad
 * Handle the Export command to export a folder to a scratchpad.
 */
-(IBAction)exportCIXScratchpad:(id)sender
{
	[self exportSavePanel:@selector(handleCIXScratchpadExport:)];
}

/* exportSavePanel
 * Shared code that displays the File Save panel for the export logic.
 */
-(void)exportSavePanel:(SEL)exportHandler
{
	NSSavePanel * panel = [NSSavePanel savePanel];
	
	[panel beginSheetForDirectory:nil
							 file:@""
				   modalForWindow:mainWindow
					modalDelegate:self
				   didEndSelector:@selector(exportSavePanelDidEnd:returnCode:contextInfo:)
					  contextInfo:exportHandler];
}

/* exportSavePanelDidEnd
 * Called when the user completes the Export save panel
 */
-(void)exportSavePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[panel orderOut:self];
		[self performSelector:(SEL)contextInfo withObject:[panel filename]];
	}
}

/* handleCIXScratchpadExport
 * Handles a CIX scratchpad export.
 */
-(void)handleCIXScratchpadExport:(NSString *)exportFileName
{
	if (!exportController)
		exportController = [[ExportController alloc] init];
	
	// The input to the main export function is an array of all the folders to be exported.
	// Presently this is the selected folder and all sub-folders. Later this could be a
	// disjoint selection. That's why an array makes sense here.
	[exportController export:mainWindow
				  pathToFile:exportFileName
					database:db
			  arrayOfFolders:[foldersTree folders:[foldersTree actualSelection]]];
}

/* handleRSSSubscriptionsExport
 * Export a list of RSS subscriptions.
 */
-(void)handleRSSSubscriptionsExport:(NSString *)exportFileName
{
	XMLParser * newTree = [[XMLParser alloc] initWithEmptyTree];
	XMLParser * opmlTree = [newTree addTree:@"opml" withAttributes:[NSDictionary dictionaryWithObject:@"1.0" forKey:@"version"]];
	int countExported = 0;

	// Create the header section
	XMLParser * headTree = [opmlTree addTree:@"head"];
	if (headTree != nil)
	{
		[headTree addTree:@"title" withElement:@"Vienna Subscriptions"];
		[headTree addTree:@"dateCreated" withElement:[[NSCalendarDate date] description]];
	}
	
	// Create the body section
	XMLParser * bodyTree = [opmlTree addTree:@"body"];
	NSArray * feedArray = [db arrayOfRSSFolders];
	NSEnumerator * enumerator = [feedArray objectEnumerator];
	RSSFolder * rssFolder;
	
	while ((rssFolder = [enumerator nextObject]) != nil)
	{
		NSMutableDictionary * itemDict = [NSMutableDictionary dictionary];
		NSString * name = [[rssFolder folder] name];
		NSString * link = [[rssFolder folder] link];
		NSString * description = [[rssFolder folder] description];
		NSString * url = [rssFolder subscriptionURL];

		[itemDict setObject:@"rss" forKey:@"type"];
		[itemDict setObject:(name ? name : @"") forKey:@"title"];
		[itemDict setObject:(link ? link : @"") forKey:@"htmlUrl"];
		[itemDict setObject:[XMLParser quoteAttributes:(url ? url : @"")] forKey:@"xmlUrl"];
		[itemDict setObject:(description ? description : @"") forKey:@"description"];
		[bodyTree addClosedTree:@"outline" withAttributes:itemDict];
		++countExported;
	}
	
	// Now write the complete XML to the file
	if (![[NSFileManager defaultManager] createFileAtPath:exportFileName contents:nil attributes:nil])
	{
		NSBeginCriticalAlertSheet(NSLocalizedString(@"Cannot open export file message", nil),
								  NSLocalizedString(@"OK", nil),
								  nil,
								  nil, [NSApp mainWindow], self,
								  nil, nil, nil,
								  NSLocalizedString(@"Cannot open export file message text", nil));
	}
	else
	{
		NSFileHandle * fileHandle = [NSFileHandle fileHandleForWritingAtPath:exportFileName];
		NSMutableString * xmlString = [[NSMutableString alloc] initWithString:[newTree xmlForTree]];
		[xmlString replaceString:@"><" withString:@">\n<"];

		NSData * msgData = [NSData dataWithBytes:[xmlString UTF8String] length:[xmlString length]];
		[xmlString release];
		[fileHandle writeData:msgData];
		[fileHandle closeFile];
	}

	// Announce how many we successfully imported
	NSString * successString = [NSString stringWithFormat:NSLocalizedString(@"%d subscriptions successfully exported", nil), countExported];
	NSRunAlertPanel(NSLocalizedString(@"RSS Subscription Export Title", nil), successString, NSLocalizedString(@"OK", nil), nil, nil);
	
	// Clean up at the end
	[newTree release];
}
@end
