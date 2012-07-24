//
//  Connect.m
//  Vienna
//
//  Created by Steve on Thu Mar 04 2004.
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
#import "AppController.h"
#import "Connect.h"
#import "ConnectProtocol.h"
#import "StringExtensions.h"
#import "PreferenceNames.h"
#import "SSHSocket.h"
#import "TCPSocket.h"
#import "RichXMLParser.h"

// Conditional lock variables
#define NO_DATA		0
#define HAS_DATA	1

#define MAX_LINE   32

// Structure for encapsulating a message, a folder and some flags
typedef struct
{
	NSString * folderPath;
	unsigned int permissions;
	unsigned int mask;
	VMessage * message;
	NSDate * lastUpdate;
} ThreadFolderData;

// Structure for encapsulating RSS folder update info
typedef struct
{
	int folderId;
	NSString * folderPath;
	NSDate * lastUpdate;
	NSString * title;
	NSString * description;
	NSString * link;
} RSSFolderUpdateData;

// Structure for encapsulating CIX folder update info
typedef struct
{
	NSString * folderPath;
	NSString * description;
} CIXFolderUpdateData;

// Private functions
@interface Connect (Private)
	-(void)pushBackLine:(NSString *)line;
	-(NSString *)readLine:(BOOL *)endOfFile;
	-(BOOL)writeLine:(NSString *)string;
	-(BOOL)writeStringWithFormat:(BOOL)echo string:(NSString *)string, ...;
	-(BOOL)writeString:(BOOL)echo string:(NSString *)string;
	-(BOOL)writeLineUsingEncoding:(NSString *)string encoding:(NSStringEncoding)encoding;
	-(char)readServiceChar:(BOOL *)endOfFile;
	-(int)collectScratchpad;
	-(void)readAndScanForMainPrompt:(BOOL *)endOfFile;
	-(int)readAndScanForStrings:(NSArray *)stringsToScan endOfFile:(BOOL *)endOfFile;
	-(int)getMessages:(VTask *)task;
	-(void)postMessages:(VTask *)task;
	-(void)resignFolder:(VTask *)task;
	-(void)joinFolder:(VTask *)task;
	-(void)getConferenceInfo:(VTask *)task;
	-(void)fileMessages:(VTask *)task;
	-(BOOL)enterFolder:(VTask *)task;
	-(void)withdrawMessage:(VTask *)task;
	-(void)updateFullList:(VTask *)task;
	-(void)skipBack:(VTask *)task;
	-(void)setCIXBack:(VTask *)task;
	-(void)getResume:(VTask *)task;
	-(void)putResume:(VTask *)task;
	-(void)addToDatabase:(NSData *)data;
	-(void)addRSSMessageToDatabase:(NSData *)data;
	-(void)addRetrievedForum:(Forum *)forum;
	-(void)cleanForumsList;
	-(void)addRetreivedResume:(NSString *)resumeText;
	-(void)refreshRSSThread:(NSObject *)object;
@end

// Static functions
int messageDateSortHandler(VMessage * item1, VMessage * item2, void * context);

@implementation Connect

/* initWithCredentials
 * Initialise the class
 */
-(id)initWithCredentials:(Credentials *)theCredentials
{
	if ((self = [super init]) != nil)
	{
		credentials = theCredentials;
		socket = nil;
		delegate = nil;
		isCIXThreadRunning = NO;
		isRSSThreadRunning = NO;
		taskRunningCount = 0;
		cixAbortFlag = NO;
		rssAbortFlag = NO;
		shuttingDown = NO;
		online = NO;
		isPushedLine = NO;
		pushedLine = nil;
		messagesToPost = nil;
		rssArray = nil;
		messagesCollected = 0;
		usingSSH = NO;
		connectMode = MA_ConnectMode_Both;
		condLock = [[NSConditionLock alloc] initWithCondition:NO_DATA];
	}
	return self;
}

/* username
 * Return the user name associated with this connection
 */
-(NSString *)username
{
	return [credentials username];
}

/* password
 * Returns the password associated with this connection
 */
-(NSString *)password
{
	return [credentials password];
}

/* setOnline
 * Specify whether the connection operates in online or offline mode. In online mode
 * we don't disconnect after processing tasks.
 */
-(void)setOnline:(BOOL)theOnline
{
	online = theOnline;
	if (taskRunningCount)
	{
		cixAbortFlag = YES;
		rssAbortFlag = YES;
	}
	// CC: This next line locks the condition so the following unlock will
	// succeed!
	[condLock tryLockWhenCondition:HAS_DATA];
	[condLock unlockWithCondition:HAS_DATA];
}

/* setDelegate
 * Set the delegate object to which the connect code will
 * send status information.
 */
-(void)setDelegate:(id)newDelegate
{
	[newDelegate retain];
	[delegate release];
	delegate = newDelegate;
}

/* setMode
 * Both / RSS or Cix
 */
-(void)setMode:(int)newMode
{
	connectMode = newMode;
}


/* setDatabase
 * Set the database to be used by the connection
 */
-(void)setDatabase:(Database *)newDatabase
{
	[newDatabase retain];
	[db release];
	db = newDatabase;
}

/* abortConnect
 * Trigger a cancel of the connection. This call is asynchronous and
 * returns once it has set the flag. The actual cancel may take a bit
 * longer to happen.
 */
-(void)abortConnect
{
	cixAbortFlag = YES;
	rssAbortFlag = YES;
}

/* isProcessing
 * Returns whether or not a task is being processed.
 */
-(BOOL)isProcessing
{
	return taskRunningCount > 0;
}

/* messagesCollected
 * Return the number of messages collected in the last connect.
 */
-(unsigned int)messagesCollected
{
	return messagesCollected;
}

/* serviceString
 * Returns the service name used for this connection.
 */
-(NSString *)serviceString
{
	return [NSString stringWithFormat:@"%@:%d", [socket address], [socket port]];
}

/* processSingleTask
 * Process the specified task only.
 */
-(void)processSingleTask:(VTask *)task
{
	NSAssert(db != nil, @"Forgot to setDatabase first");

	// Special case for post messages task
	if ([task actionCode] == MA_TaskCode_PostMessages)
	{
		// Compose messagesToPost. The database code doesn't allow calling on separate threads
		// so we need to collect this information up-front.
		BOOL sortedFlag;
		NSArray * messagesInOutbox = [db arrayOfMessages:MA_Outbox_NodeID filterString:nil withoutIgnored:NO sorted:&sortedFlag];
		NSEnumerator * enumerator = [messagesInOutbox objectEnumerator];
		VMessage * message;
		
		// The Connect object is shared so we need to remember to
		// release the array we may have allocated last time we came
		// through here.
		[messagesToPost release];
		messagesToPost = [[NSMutableArray alloc] init];
		
		while ((message = [enumerator nextObject]) != nil)
		{
			// We need to ask the delegate because there may be reasons why an Out Basket
			// message cannot be posted. For example, it is probably still being edited.
			if ([delegate canPostMessage:MA_Outbox_NodeID messageNumber:[message messageId]])
			{
				NSString * messageText = [db messageText:MA_Outbox_NodeID messageId:[message messageId]];
				[message setText:messageText];
				[messagesToPost addObject:message];
			}
		}
	}
	
	// If the task is a PutResume, attach the VPerson for the current user
	// to the task object.
	if ([task actionCode] == MA_TaskCode_PutResume)
	{
		VPerson * person = [db retrievePerson:[credentials username]];
		[task setActionData:[person info]];
		// static analyser complains 
		// [person release];
	}

	// Handle RSS connections specially. Create a local array of all RSS sites
	// before we run the thread.
	if ([task actionCode] == MA_TaskCode_GetRSS)
	{
		if (!isRSSThreadRunning)
		{
			[rssArray release];
			rssArray = [[db arrayOfRSSFolders] retain];
			if (rssArray != nil && [rssArray count] > 0)
				[NSThread detachNewThreadSelector:@selector(refreshRSSThread:) toTarget:self withObject:task];
		}
		return;
	}
	
	// Add the task to the connection's task array
	[condLock lock];
	if (tasksArray == nil)
		tasksArray = [[NSMutableArray alloc] init];
	[tasksArray addObject:task];
	[condLock unlockWithCondition:HAS_DATA];

	// Now kick off the thread if it isn't running
	if (!isCIXThreadRunning)
	{
		isCIXThreadRunning = YES;
		[NSThread detachNewThreadSelector:@selector(connectThread:) toTarget:self withObject:nil];
	}
}

/* processOfflineTasks
 * Do an offline task connect which consists of posting messages from the Out Basket,
 * reading new messages and carrying out any other active tasks in the task queue.
 */
-(void)processOfflineTasks
{
	NSAssert(db != nil, @"Forgot to setDatabase first");
	
	// Add read and post tasks to the task list if they're not already there
	[db addTask:MA_TaskCode_PostMessages actionData:@"" folderName:@"" orderCode:MA_OrderCode_PostMessages];
	[db addTask:MA_TaskCode_ReadMessages actionData:@"" folderName:@"" orderCode:MA_OrderCode_ReadMessages];
	[db addTask:MA_TaskCode_GetRSS actionData:@"" folderName:@"" orderCode:MA_OrderCode_GetRSS];

	// Reset count of messages collected
	messagesCollected = 0;
	cixAbortFlag = NO;
	rssAbortFlag = NO;
	
	// Now add everything in the db task list to the connection task
	// array.
	NSArray * array = [db arrayOfTasks:YES];
	NSEnumerator * enumerator = [array objectEnumerator];
	VTask * task;

	while ((task = [enumerator nextObject]) != nil)
	{
		if ([task actionCode] == MA_TaskCode_GetRSS) 
		{
			if (connectMode == MA_ConnectMode_RSS ||
				connectMode == MA_ConnectMode_Both)
			[self processSingleTask:task];
		}
		else
		{
			if (connectMode == MA_ConnectMode_Cix ||
				connectMode == MA_ConnectMode_Both)
			[self processSingleTask:task];
		}
	}
}

/* markMessagePosted
 * This function is called from the thread after the specified message is successfully
 * posted. We remove it from the Out Basket.
 */
-(void)markMessagePosted:(VMessage *)message
{
	[db deleteMessage:MA_Outbox_NodeID messageNumber:[message messageId]];
	[self updateLastFolder:[NSNumber numberWithInt:MA_Outbox_NodeID]];
}

/* taskCompleted
 */
-(void)taskCompleted:(VTask *)task
{
	NSAssert(taskRunningCount > 0, @"Called taskCompleted but taskRunningCount is zero");
	[db setTaskCompleted:task];
	[delegate taskStatus:YES];
	--taskRunningCount;
}

/* taskStarted
 */
-(void)taskStarted:(VTask *)task
{
	++taskRunningCount;
	[delegate taskStatus:NO];
	[db setTaskRunning:task];
}

/* updateLastFolder
 * If the folder ID passed to this function is different from the folder ID when this function
 * was last called, we use this as a cue to tell the folder view to redraw itself so that changes
 * in the read/unread count are reflected in the folder name or style.
 */
-(void)updateLastFolder:(NSNumber *)number
{
	int topicId = [number intValue];
	if (topicId != lastTopicId && lastTopicId != -1)
	{
		[db flushFolder:lastTopicId];
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithInt:lastTopicId]];
	}
	lastTopicId = topicId;
}

/* addToDatabase
 * Called from the thread with a new folder or message to be added to the database.
 */
-(void)addToDatabase:(NSData *)data
{
	ThreadFolderData * threadData = (ThreadFolderData *)[data bytes];
	NSAssert(threadData->folderPath != nil, @"threadData->folderPath cannot be nil");

	if (threadData->message != nil)
	{
		BOOL wasNew;

		[db addMessageToFolder:[db conferenceNodeID] path:threadData->folderPath message:threadData->message raw:NO wasNew:&wasNew];
		[self updateLastFolder:[NSNumber numberWithInt:[threadData->message folderId]]];
		if (wasNew)
			++messagesCollected;
	}
	else
	{
		int folderId = [db addFolderByPath:[db conferenceNodeID] path:threadData->folderPath];
		if (folderId != -1)
		{
			if (threadData->mask & MA_LockedFolder)
			{
				[db markFolderLocked:folderId isLocked:(threadData->permissions & MA_LockedFolder) == MA_LockedFolder];
				[self updateLastFolder:[NSNumber numberWithInt:folderId]];
			}
		}
	}
}

/* addRSSMessageToDatabase
 * Called from the thread with a new RSS message to be added to the database.
 */
-(void)addRSSMessageToDatabase:(NSData *)data
{
	ThreadFolderData * threadData = (ThreadFolderData *)[data bytes];
	int folderId = [threadData->message folderId];
	BOOL wasNew;

	[db addMessage:folderId message:threadData->message wasNew:&wasNew];
	[self updateLastFolder:[NSNumber numberWithInt:folderId]];
	if (wasNew)
		++messagesCollected;
}	

/* updateRSSFolder
 * Update information on an RSS folder.
 */
-(void)updateRSSFolder:(NSData *)data
{
	RSSFolderUpdateData * threadData = (RSSFolderUpdateData *)[data bytes];
	Folder * folder = [db folderFromID:threadData->folderId];

	if ([[folder name] isEqualToString:@"(Untitled Feed)"])
		[db setFolderName:threadData->folderId newName:threadData->title];
	if (threadData->description != nil)
		[db setFolderDescription:threadData->folderId newDescription:threadData->description];
	if (threadData->link != nil)
		[db setFolderLink:threadData->folderId newLink:threadData->link];
	[db setRSSFeedLastUpdate:threadData->folderId lastUpdate:threadData->lastUpdate];
}

/* updateFolder
 * Update information on an standard folder.
 */
-(void)updateFolder:(NSData *)data
{
	CIXFolderUpdateData * threadData = (CIXFolderUpdateData *)[data bytes];
	int folderId = [db addFolderByPath:[db conferenceNodeID] path:threadData->folderPath];
	if (folderId != -1)
		[db setFolderDescription:folderId newDescription:threadData->description];
}

/* addRetrievedForum
 * Called from the thread with a new forum to be added to the database.
 */
-(void)addRetrievedForum:(Forum *)forum
{
	if (forum != nil)
		[db addForum:forum];
	else
	{
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_ForumsUpdated" object:nil];
	}
}

-(void)cleanForumsList;
{
	[db cleanBrowserTables];
}

/* addCategory
 * Add the specified category to the database.
 */
-(void)addCategory:(Category *)newCategory
{
	[db addCategory:newCategory];
}

/* addRetrievedResume
 * Add a resume to the database. The first line of the resume is the
 * person name.
 */
-(void)addRetrievedResume:(NSString *)resumeText
{
	NSScanner * scanner = [NSScanner scannerWithString:resumeText];
	NSString * name;
	NSString * info;

	[scanner scanUpToString:@" " intoString:&name];
	[scanner scanUpToString:@"\n" intoString:nil];
	if (![scanner scanUpToString:@"" intoString:&info])
		info = @"";
	[db updatePerson:name data:info];
}

/* sendActivityStringToDelegate
 * Calls the delegate function passing a string to be shown in the activity window
 */
-(void)sendActivityStringToDelegate:(NSString *)string
{
	if (delegate != nil)
		[delegate performSelectorOnMainThread:@selector(activityString:) withObject:string waitUntilDone:NO];
}

/* sendStartConnectToDelegate
 * Calls the delegate function advising it that a connect has started
 */
-(void)sendStartConnectToDelegate
{
	if (delegate != nil && taskRunningCount == 0)
		[delegate performSelectorOnMainThread:@selector(startConnect:) withObject:nil waitUntilDone:YES];
}

/* sendEndConnectToDelegate
 * Calls the delegate function advising it that a connect has ended
 */
-(void)sendEndConnectToDelegate:(int)result
{
	if (delegate != nil && taskRunningCount == 0)
		[delegate performSelectorOnMainThread:@selector(endConnect:) withObject:[NSNumber numberWithInt:result] waitUntilDone:YES];
}

/* sendStatusToDelegate
 * Sends a status string to the delegate
 */
-(void)sendStatusToDelegate:(NSString *)statusString
{
	if (delegate != nil)
		[delegate performSelectorOnMainThread:@selector(setStatusMessage:) withObject:statusString waitUntilDone:YES];
}

/* refreshRSSThread
 * Refreshing the RSS feeds occurs on a separate thread from CIX since it doesn't
 * need to be serialised or uses the CIX socket.
 */
-(void)refreshRSSThread:(NSObject *)object
{
	NSAutoreleasePool * pool;
	VTask * task = (VTask *)object;
	int result = MA_Connect_Success;

	// Init
    pool = [[NSAutoreleasePool alloc] init];
	isRSSThreadRunning = YES;
	int taskResult = MA_Connect_Success;
	NSString * taskData = @"";

	// Communicate that a task has started.
	[task retain];
	[self performSelectorOnMainThread:@selector(taskStarted:) withObject:task waitUntilDone:YES];
	if (connectMode == MA_ConnectMode_RSS)
	{
		[self sendStatusToDelegate: NSLocalizedString(@"Updating RSS subscriptions", nil)];
	}


	// Populate the RSS GUIDs dictionary
	[db performSelectorOnMainThread:@selector(loadRSSGuids:) withObject:task waitUntilDone:YES];
	NSMutableDictionary * RSSGuids = [db getRSSGuids];
	
	// Loop for every array in rssArray. This can be either every single RSS folder or just
	// a selection of RSS folders. We don't care.
	NSEnumerator * folderEnumerator = [rssArray objectEnumerator];
	RSSFolder * rssFolder;
	
	while ((rssFolder = [folderEnumerator nextObject]) && !rssAbortFlag)
	{
		NSMutableArray * messageArray = [NSMutableArray array];
		NSDate * newLastUpdate = nil;
		BOOL isUntitledFeed = [[[rssFolder folder] name] isEqualToString:@"(Untitled Feed)"];

		// Send status
		NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Updating subscription from '%@'", nil), [[rssFolder folder] name]];
		[self sendStatusToDelegate:statusString];

		// Get the feed
		RichXMLParser * newFeed = [[RichXMLParser alloc] init];
		if ([newFeed loadFromURL:[rssFolder subscriptionURL]])
		{
			// Keep track of the date of the most recent item. We use this to ignore items we
			// already have.
			NSDate * lastUpdate = [rssFolder lastUpdate];

			// Extract the latest title and description
			NSString * feedTitle = [newFeed title];
			NSString * feedDescription = [newFeed description];
			NSString * feedLink = [newFeed link];

			// If the untitled feed now has a title, change the status
			if (isUntitledFeed && feedTitle != nil)
			{
				NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Updating subscription from '%@'", nil), feedTitle];
				[self sendStatusToDelegate:statusString];
			}
			
			// Get the feed's last update from the header if it is present. This will mark the
			// date of the most recent message in the feed if the individual messages are
			// missing a date tag.
			// Note: some feeds appear to have a lastModified in the header that is out of
			//   date compared to the items in the feed. So do a sanity check to ensure that
			//   the date on the items take precedence.
			if ([[newFeed lastModified] isGreaterThan:lastUpdate])
			{
				newLastUpdate = [[newFeed lastModified] retain];
			}
			if (newLastUpdate == nil)
				newLastUpdate = [lastUpdate retain];

			// Parse off items.
			NSEnumerator * itemEnumerator = [[newFeed items] objectEnumerator];
			FeedItem * newsItem;

			while ((newsItem = [itemEnumerator nextObject]) && !rssAbortFlag)
			{
				NSDate * messageDate = [newsItem date];
				int msgFlag = MA_MsgID_New;
				NSString * guid = [newsItem guid];
				
				// If the article doesn't have a GUID then synthesize one.
				// This code nicked from Steve's Vienna2 RefreshManager.m
				if (guid == nil || [guid isEqualToString:@""])
				{
					guid = [NSString stringWithFormat:@"%d-%@-%@", [rssFolder folderId], [newsItem link], [newsItem title]];
					[newsItem setGuid: guid];
				}

				// If no dates anywhere then use MA_MsgID_RSSNew as the message number to
				// force the database to locate a previous copy of this message if there
				// is one.
				if (messageDate == nil)
				{
					messageDate = [NSCalendarDate date];
					msgFlag = MA_MsgID_RSSNew;
				}
				
				// Now insert the message into the database if it is newer than the
				// last update for this feed.
				if ([messageDate isGreaterThan:lastUpdate])
				{				
					// Exclude matching GUIDs IFF titles also match
					NSString *dup = [RSSGuids objectForKey: guid];
					if (dup != nil)
					{
						// Quick sanity check that it really is the same message
						if ([[newsItem title] isEqualToString: dup])
							continue;
					}
				
					NSString * messageBody = [newsItem description];
					NSString * messageTitle = [newsItem title];
					NSString * messageLink = [newsItem link];
					NSString * userName = [newsItem author];
					
					// Make sure we don't get any duplicates of this new article
					[RSSGuids setObject: [newsItem title] forKey: guid];

					// Format the message body complete with title and link.
					NSMutableString * formattedMessageBody = [NSMutableString stringWithFormat:
								@"<HTML><HEAD></HEAD><BODY><B>%@</B><BR><BR>%@",
								messageTitle,
								messageBody];
					if (messageLink != nil)
						[formattedMessageBody appendFormat:@"<BR><BR><A HREF=\"%@\">%@</A>\n<BR>", messageLink, messageLink];
					[formattedMessageBody appendString:@"</BODY></HTML>"];

					// Create the message
					VMessage * message = [[VMessage alloc] initWithInfo:msgFlag];
					[message setComment:0];
					[message setFolderId:[rssFolder folderId]];
					[message setSender:userName];
					[message setText:formattedMessageBody];
					[message setTitle:messageTitle];
					[message setDateFromDate:messageDate];
					[message setGuid: [newsItem guid]];
					[messageArray addObject:message];
					[message release];

					// Track most current update
					if ([messageDate isGreaterThan:newLastUpdate])
					{
						[messageDate retain];
						[newLastUpdate release];
						newLastUpdate = messageDate;
					}
				}
			}

			// Now sort the message array before we insert into the
			// database so we're always inserting oldest first. The RSS feed is
			// likely to give us newest first.
			NSArray * sortedArrayOfMessages = [messageArray sortedArrayUsingFunction:messageDateSortHandler context:self];
			NSEnumerator * messageEnumerator = [sortedArrayOfMessages objectEnumerator];
			VMessage * message;

			// Here's where we add the messages to the database
			while ((message = [messageEnumerator nextObject]) != nil)
			{
				ThreadFolderData threadData;
				threadData.folderPath = nil;
				threadData.mask = 0;
				threadData.message = message;
				[self performSelectorOnMainThread:@selector(addRSSMessageToDatabase:)
									   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)]
									waitUntilDone:YES];
			}
			
			// Set the last update date for this folder to be the date of the most
			// recent article we retrieved.
			RSSFolderUpdateData threadData;
			threadData.folderId = [rssFolder folderId];
			threadData.lastUpdate = newLastUpdate;
			threadData.title = feedTitle;
			threadData.description = feedDescription;
			threadData.link = feedLink;
			[self performSelectorOnMainThread:@selector(updateRSSFolder:)
								   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)]
								waitUntilDone:YES];
		}

		// Clean up
		[newLastUpdate release];
		[newFeed release];
	}

	// Set the task result
	[task setResultCode:taskResult];
	[task setResultString:taskData];

	// Refresh UI when we're done.
	[self performSelectorOnMainThread:@selector(updateLastFolder:) withObject:[NSNumber numberWithInt:-1] waitUntilDone:NO];
	[self performSelectorOnMainThread:@selector(taskCompleted:) withObject:task waitUntilDone:YES];

	// Let caller know the result.
	if (!shuttingDown)
	{
		[self sendStatusToDelegate:nil];
		[self sendEndConnectToDelegate:result];	
	}
	
	[task release];
	isRSSThreadRunning = NO;
	[pool release];
}

/* messageDateSortHandler
 * Compares two VMessages and returns their chronological order
 */
int messageDateSortHandler(VMessage * item1, VMessage * item2, void * context)
{
	return [[item1 date] compare:[item2 date]];
}

// Join conference and enable moderator privileges
-(BOOL)setModerator:(VTask *)task
{
	BOOL endOfFile;
	int match;

	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Moderating '%@'", nil), [task folderName]];
	[self sendStatusToDelegate:statusString];
		
	if (![self enterFolder:task])
		return NO;

	[self writeLine:@"mod"];
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Mod:", @"Conference name?", nil] endOfFile:&endOfFile];
	if (endOfFile)
		return NO;

	if (match == 0)
		return YES;
	
	// match == 1, not allowed to mod this conference - remove prompt
	[self writeLine:@"quit"];
	[self readAndScanForMainPrompt:&endOfFile];

	// Fail task
	[task setResultCode:MA_TaskResult_Failed];
	[task setResultString:@"Not allowed to mod this conference"];
	return NO;
}

-(void)modAddpart:(VTask *)task
{	
	if ([self setModerator: task])
	{
		BOOL endOfFile;
		int match;
		
		[self writeStringWithFormat:YES string:@"add part %@\n", [task actionData]];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Mod:", nil] endOfFile:&endOfFile];
		[task setResultCode:MA_TaskResult_Succeeded];
		
		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
}

-(void)modRempart:(VTask *)task
{
	if ([self setModerator: task])
	{
		BOOL endOfFile;
		int match;
		
		[self writeStringWithFormat:YES string:@"rem part %@\n", [task actionData]];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Mod:", nil] endOfFile:&endOfFile];
		[task setResultCode:MA_TaskResult_Succeeded];
		
		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
}

-(void)modReadonly:(VTask *)task
{
	if ([self setModerator: task])
	{
		BOOL endOfFile;
		int match;
		
		// Extract topic name from conference/topic
		NSString * folderName = [task folderName];
		NSString * topicName = [folderName lastPathComponent];
		
		// Rdonly is a toggle
		[self writeStringWithFormat:YES string:@"rdonly %@\n", topicName];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Setting to Read Write", @"Setting to Read Only", @"Mod:", nil] endOfFile:&endOfFile];
		if (match == 0)
		{
			[task setResultCode:MA_TaskResult_Succeeded];
			[task setResultString:@"Topic set to Read Write"];
		}
		if (match == 1)
		{
			[task setResultCode:MA_TaskResult_Succeeded];
			[task setResultString:@"Topic set to Read Only"];
		}
		
		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
}

-(void)modComod:(VTask *)task
{
	if ([self setModerator: task])
	{
		BOOL endOfFile;		
		int match;
		
		[self writeStringWithFormat:YES string:@"comod %@\n", [task actionData]];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Mod:", nil] endOfFile:&endOfFile];
		[task setResultCode:MA_TaskResult_Succeeded];
		
		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
	}
}

-(void)modExmod:(VTask *)task
{
	if ([self setModerator: task])
	{
		BOOL endOfFile;
		int match;
		
		[self writeStringWithFormat:YES string:@"exmod %@\n", [task actionData]];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Mod:", nil] endOfFile:&endOfFile];
		[task setResultCode:MA_TaskResult_Succeeded];
		
		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
}

-(void)modAddTopic:(VTask *)task
{
	if ([self setModerator: task])
	{
		BOOL endOfFile;
		int match;
		NSArray *listItems = [[task actionData] componentsSeparatedByString:@":"];
		NSString *topicName = [listItems objectAtIndex:0];
		NSString *hasFlist = [listItems objectAtIndex:1];
		NSString *topicDescription = [listItems objectAtIndex:2];

		[self writeLine:@"add topic"];

		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Topicname:", nil] endOfFile:&endOfFile];
		[self writeLine:topicName];

		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"FLIST) (y/n)? ", @"already exists", nil] endOfFile:&endOfFile];
		if (match == 0)
		{
			[self writeLine:hasFlist];

			match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"escription of ", nil] endOfFile:&endOfFile];
			[self writeLine:topicDescription];

			match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"another topicname", nil] endOfFile:&endOfFile];
			[task setResultCode:MA_TaskResult_Succeeded];
	    }
		else
		{
			[task setResultCode:MA_TaskResult_Failed];
			[task setResultString:@"Topic already exists"];
		}
			
		[self writeLine:@"quit"];

		// Quit back to non-moderator level
		[self writeLine:@"quit quit"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
}

-(void)modNewconf:(VTask *)task
{
	if ([self setModerator: task])
	{
		// TODO
	}
}

// Send a file via Zmodem
-(int)zmodemSend:(NSString *)fileName;
{
	NSTask *zmTask;
	NSFileHandle *fh;
	NSString *execFile = [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"sz"];
	int status;
	
	// Can't find 
	if (execFile == nil) {
		NSLog(@"Can't find sz");
		return -1;
	}
		
	[socket setNonBlocking: NO];
	fh = [[NSFileHandle alloc] initWithFileDescriptor: [socket getFd]];
	
	zmTask = [[NSTask alloc] init];
	[zmTask setLaunchPath: execFile];
	[zmTask setArguments: [NSArray arrayWithObjects: @"--zmodem", @"-q", @"-y", @"-b", fileName, nil]];
	[zmTask setStandardOutput: fh];
	[zmTask setStandardInput: fh];

	[zmTask launch];
	[zmTask waitUntilExit];
	
	status = [zmTask terminationStatus];
	[zmTask release];
	[fh release];
	
	[socket setNonBlocking: YES];
	
	return status;
}


// Receive a file via Zmodem
-(int)zmodemReceive:(NSString *)downloadFolder;
{
	NSTask *zmTask;
	NSFileHandle *fh;
	NSString *execFile = [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"rz"];
	int status;
	
	// Can't find 
	if (execFile == nil) {
		NSLog(@"Can't find rz");
		return -1;
	}
	[socket setNonBlocking: NO];
	fh = [[NSFileHandle alloc] initWithFileDescriptor: [socket getFd]];
	
	zmTask = [[NSTask alloc] init];
	[zmTask setLaunchPath: execFile];
	[zmTask setArguments: [NSArray arrayWithObjects: @"-Z", @"-b", @"-q", @"-y", nil]];
	[zmTask setStandardOutput: fh];
	[zmTask setStandardInput: fh];
	[zmTask setCurrentDirectoryPath: downloadFolder];

	[zmTask launch];
	[zmTask waitUntilExit];

	status = [zmTask terminationStatus];
	[zmTask release];
	[fh release];
	
	[socket setNonBlocking: YES];
	
	return status;
}

-(void)downloadFile:(VTask *)task
{
	BOOL endOfFile;
	int match;
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Downloading '%@/%@'", nil), [task folderName], [task actionData]];
	[self sendStatusToDelegate:statusString];
	
	if (![self enterFolder:task])
		return;
	
	[self writeStringWithFormat:YES string:@"fdl %@\n", [task actionData]];
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"is-spelled?)", @"ail the moderator", @"ailed", @"Batch Mode", nil] endOfFile:&endOfFile];
	if (match == 0 || match == 1 || match == 2)
	{
		[task setResultCode:MA_TaskResult_Failed];
	}
	else
	{
		int status;
		NSString *downloadFolder;
		
		// Download mugshots into the mugshots folder if asked to do so
		if ([defaults boolForKey:MAPref_DetectMugshotDownload] && [[task folderName] hasPrefix : @"mugshots/"])	
			downloadFolder = [[defaults stringForKey:MAPref_MugshotsFolder] stringByExpandingTildeInPath];
		else
			downloadFolder = [[defaults stringForKey: MAPref_DownloadFolder] stringByExpandingTildeInPath];	
		
		status = [self zmodemReceive: downloadFolder];
		if (status == 0)
		{
			[task setResultCode:MA_TaskResult_Succeeded];
			NSString * statusString = NSLocalizedString(@"Download completed", nil);
			[task setResultString: [NSString stringWithFormat: @"Downloaded to %@", downloadFolder]];
			[self sendStatusToDelegate:statusString];
		}
		else
		{
			[task setResultCode:MA_TaskResult_Failed];
			[task setResultString: @"Download failed"];
			NSString * statusString = NSLocalizedString(@"Download failed", nil);
			[self sendStatusToDelegate:statusString];
		}
	}
	
	// Quit back to "main" mode
	[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
	[self writeLine:@"quit"];
	[self readAndScanForMainPrompt:&endOfFile];
}

-(void)uploadFile:(VTask *)task
{
	BOOL endOfFile;
	int match;
	
	// Check file exists so we don't have to cope with a Zmodem error
	if (![[NSFileManager defaultManager] isReadableFileAtPath: [task actionData]])
	{
		NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Can't open %@ to upload", nil), [task actionData]];
		[self sendStatusToDelegate:statusString];
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString: @"Can't open file"];
		return;
	}
	
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"uploading %@ to %@", nil), [task actionData], [task folderName]];
	[self sendStatusToDelegate:statusString];
	
	if (![self enterFolder:task])
		return;
	
	[self writeLine:@"ful"];	
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"No FLIST found!", @"to receive", nil] endOfFile:&endOfFile];
	if (match == 0)
	{
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString: @"No FLIST"];
	}
	else
	{
		int status;
		
		status = [self zmodemSend: [task actionData]];
		if (status == 0)
		{
			[task setResultCode:MA_TaskResult_Succeeded];
			[task setResultString: @""]; // Just in case it previously failed :)
			NSString * statusString = NSLocalizedString(@"Upload completed", nil);
			[self sendStatusToDelegate:statusString];
		}
		else
		{
			[task setResultCode:MA_TaskResult_Failed];
			[task setResultString: @"Upload failed"];
			NSString * statusString = NSLocalizedString(@"Upload failed", nil);
			[self sendStatusToDelegate:statusString];
		}
	}
	
	// Quit back to "main" mode
	[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
	[self writeLine:@"quit"];
	[self readAndScanForMainPrompt:&endOfFile];
}


/* connectThread
 * This is the actual thread that runs to connect to the service and retrieve new
 * messages. It runs as long as we're online takes its feed from the tasksArray
 * array which we handle as a queue.
 */
-(void)connectThread:(NSObject *)object
{
	NSAutoreleasePool * pool;
	int result = MA_Connect_Success;
	VTask * task;
	unsigned int index;

    pool = [[NSAutoreleasePool alloc] init];
	index = 0;
	lastTopicId = -1;
	while (!cixAbortFlag && !shuttingDown)
	{
		[condLock lockWhenCondition:HAS_DATA];
		if (shuttingDown)
		    break;

		while(index < [tasksArray count])
		{
			task = [tasksArray objectAtIndex:index];
			[condLock unlockWithCondition:HAS_DATA];
			
			// Check we're still connected
			if (![socket isConnected])
			{
				[self sendStartConnectToDelegate];
				if ((result = [self connectToService]) != MA_Connect_Success)
				{
					cixAbortFlag = YES;
					break;
				}
			}

			[self performSelectorOnMainThread:@selector(taskStarted:) withObject:task waitUntilDone:YES];
			switch ([task actionCode])
			{
			case MA_TaskCode_ConfList:
				[self updateFullList:task];
				break;

			case MA_TaskCode_PostMessages:
				[self postMessages:task];
				break;

			case MA_TaskCode_ReadMessages:
				[self getMessages:task];
				break;

			case MA_TaskCode_JoinFolder:
				[self joinFolder:task];
				break;

			case MA_TaskCode_GetResume:
				[self getResume:task];
				break;
				
			case MA_TaskCode_PutResume:
				[self putResume:task];
				break;
				
			case MA_TaskCode_FileMessages:
				[self fileMessages:task];
				break;
				
			case MA_TaskCode_ResignFolder:
				[self resignFolder:task];
				break;
				
			case MA_TaskCode_WithdrawMessage:
				[self withdrawMessage:task];
				break;
				
			case MA_TaskCode_SkipBack:
				[self skipBack:task];
				break;

			case MA_TaskCode_SetCIXBack:
				[self setCIXBack:task];
				break;

			case MA_TaskCode_FileDownload:
				[self downloadFile:task];
				break;

			case MA_TaskCode_FileUpload:
				[self uploadFile:task];
				break;
				
			case MA_TaskCode_ModAddPart:
				[self modAddpart:task];
				break;
			case MA_TaskCode_ModRemPart:
				[self modRempart:task];
				break;
			case MA_TaskCode_ModNewConf:
				[self modNewconf:task];
				break;
			case MA_TaskCode_ModRdOnly:
				[self modReadonly:task];
				break;
			case MA_TaskCode_ModAddTopic:
				[self modAddTopic:task];
				break;
			case MA_TaskCode_ModComod:
				[self modComod:task];
				break;
			case MA_TaskCode_ModExmod:
				[self modExmod:task];
				break;
			}
			[self performSelectorOnMainThread:@selector(taskCompleted:) withObject:task waitUntilDone:NO];
			[condLock lockWhenCondition:HAS_DATA];
			++index;
		}
		
		// Empty the queue when we reach the last item. This is to ensure that
		// we don't grow it unnecessarily and eat up memory. Note that we should
		// have acquired a lock by the time we get here.
		[tasksArray release];
		tasksArray = nil;
		index = 0;
		[condLock unlockWithCondition:NO_DATA];
		[self sendStatusToDelegate:nil];
		
		// If we're not in online mode then as soon as the tasks queue
		// is empty, we exit and kill the thread.
		if (!online)
			break;
	}
	// Disconnect when we're done
	[self disconnectFromService];

	// Let caller know the result.
	if (!shuttingDown)
	{
		[self sendStatusToDelegate:nil];
		[self sendEndConnectToDelegate:result];	
	}

	// This is the right place to close the socket
	[socket close];
	[socket release];
	socket = nil;
	shuttingDown = NO;
	isCIXThreadRunning = NO;
	[condLock unlockWithCondition:NO_DATA];
	[pool release];
}

/* stopCIXConnectThread
 * synchronously get the cix connect thread to shut down.
 */
-(void)stopCIXConnectThread
{
    if (isCIXThreadRunning)
    {
		shuttingDown = YES;
		[condLock unlockWithCondition:HAS_DATA];

		// Wait till the thread has finished
		[condLock lockWhenCondition:NO_DATA];
    }
} 

/* getMessages
 * Read all new messages from the service.
 */
-(int)getMessages:(VTask *)task
{
	BOOL endOfFile;
	int result = MA_Connect_Success;
	NSString * taskData = @"";
	int taskResult = MA_TaskResult_Succeeded;
	BOOL needRecovery = [[NSUserDefaults standardUserDefaults] boolForKey:MAPref_Recovery];

	// Set recovery depending on last state. Do this now in case the app or machine crashes
	// before the download completes.
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:MAPref_Recovery];

	// Retrieve existing scratchpad if last connect failed
	if (needRecovery)
	{
		[self sendStatusToDelegate:NSLocalizedString(@"Recovering last failed connection", nil)];
		result = [self collectScratchpad];
		if (result != MA_Connect_Success)
			return result;
	}
	
	// Read all new messages into the scratchpad
	// then call collectScratchpad to dump them.
	[self sendStatusToDelegate:NSLocalizedString(@"Collecting new messages", nil)];
	[self writeLine:@"file read all"];
	[self readAndScanForMainPrompt:&endOfFile];
	if (!endOfFile)
	{
		[self sendStatusToDelegate:NSLocalizedString(@"Retrieving new messages", nil)];
		result = [self collectScratchpad];
	}

	// Set recovery depending on last state
	if (result == MA_Connect_Success)
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:MAPref_Recovery];

	// Set the task result
	[task setResultCode:taskResult];
	[task setResultString:taskData];
	return result;
}

/* collectScratchpad
 * Get the contents of the scratchpad and parse.
 */
-(int)collectScratchpad
{
	BOOL endOfFile;
	int result = MA_Connect_Success;
	BOOL isReadOnly = NO;

	// Remember current folder path because some Joining actions are split
	// across multiple lines.
	NSString * folderPath = nil;
	
	[self writeLine:@"show scratchpad"];
	NSString * line = [self readLine:&endOfFile];
	while (!endOfFile)
	{
		if ([line hasPrefix:@"No unread messages"])
			break;
		else if ([line hasPrefix:@"Your SCRATCHPAD is empty"])
			break;
		else if ([line hasPrefix:@"READ ONLY"] && folderPath != nil)
		{
			// Use a ThreadFolderData to communicate with the main thread
			ThreadFolderData threadData;
			threadData.folderPath = folderPath;
			threadData.permissions = MA_LockedFolder;
			threadData.mask = MA_LockedFolder;
			threadData.message = nil;
			[self performSelectorOnMainThread:@selector(addToDatabase:)
								   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)] 
								waitUntilDone:YES];
		}
		else if ([line hasPrefix:@"Joining "])
		{
			NSScanner * scanner = [NSScanner scannerWithString:line];
			[scanner scanString:@"Joining " intoString:nil];
			[scanner scanUpToString:@" " intoString:&folderPath];

			// Figure out if this conference is read-only
			isReadOnly = ([line hasSuffix:@"READ ONLY\n"]);
			
			// Use a ThreadFolderData to communicate with the main thread
			ThreadFolderData threadData;
			threadData.folderPath = folderPath;
			threadData.permissions = isReadOnly ? MA_LockedFolder : 0;
			threadData.mask = MA_LockedFolder;
			threadData.message = nil;
			[self performSelectorOnMainThread:@selector(addToDatabase:)
								   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)] 
								waitUntilDone:YES];
		}
		else if ([line hasPrefix:@">>>"])
		{
			NSString * messagePath;
			NSString * userName;
			NSString * messageDateString;
			NSString * messageTimeString;
			NSDate * messageDate;
			int messageNumber;
			int messageComment;
			unsigned int messageSize;
			
			messageComment = 0;
			NSScanner * scanner = [NSScanner scannerWithString:line];
			[scanner scanString:@">>>" intoString:nil];
			[scanner scanUpToString:@" " intoString:&messagePath];
			[scanner scanInt:&messageNumber];
			[scanner scanUpToString:@"(" intoString:&userName];
			[scanner scanString:@"(" intoString:nil];
			[scanner scanInt:(int *)&messageSize];
			[scanner scanString:@")" intoString:nil];
			[scanner scanUpToString:@" " intoString:&messageDateString];
			[scanner scanUpToString:@" " intoString:&messageTimeString];
			[scanner scanString:@"c" intoString:nil];
			[scanner scanInt:&messageComment];					
			
			// Convert the date and time into something we can work with
			messageDate = [NSCalendarDate dateWithString:[messageDateString stringByAppendingFormat:@" %@", messageTimeString] calendarFormat:@"%d%b%y %H:%M"];
			
			// Read the message body using the size as a clue.
			NSMutableString * messageBody;
			unsigned int messageSoFar = 0;
			
			messageBody = [[NSMutableString alloc] initWithCapacity:1024];
			while (messageSoFar < messageSize)
			{
				NSString * line = [self readLine:&endOfFile];
				if ([line length] + messageSoFar > messageSize)
				{
					// We read too far and the count on the message
					// was broken.
					[self pushBackLine:line];
					break;
				}
				if (endOfFile)
					goto abortLabel;
				messageSoFar += [line length];
				[messageBody appendString:line];
			}
			
			// Now insert the message into the database
			VMessage * message = [[VMessage alloc] initWithInfo:messageNumber];
			[message setComment:messageComment];
			[message setSender:userName];
			[message setText:messageBody];
			[message setDateFromDate:messageDate];

			// Use a ThreadFolderData to communicate with the main thread
			ThreadFolderData threadData;
			threadData.folderPath = messagePath;
			threadData.mask = 0;
			threadData.message = message;
			[self performSelectorOnMainThread:@selector(addToDatabase:)
								   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)]
								waitUntilDone:YES];
			
			// Clean up
			[message release];
			[messageBody release];
		}
		line = [self readLine:&endOfFile];
	}
	
	// Set result code if we were aborted
abortLabel:
	if (cixAbortFlag)
		result = MA_Connect_Aborted;
	[self performSelectorOnMainThread:@selector(updateLastFolder:) withObject:[NSNumber numberWithInt:-1] waitUntilDone:NO];
	
	// Blow away the scratchpad if everything went fine
	if (result == MA_Connect_Success)
	{
		[self writeLine:@"killsc"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
	return result;
}

/* updateFullList
 * Retrieve the full list of available CIX conferences.
 */
-(void)updateFullList:(VTask *)task
{
	BOOL endOfFile;
	unsigned int count = 0;
	int categoryId = -1;

	// Remove old (well, all!) entries
	[self performSelectorOnMainThread:@selector(cleanForumsList:) withObject:nil waitUntilDone:YES];
			
	// Issue the version of the command that also retrieves the last access date
	[self sendStatusToDelegate:NSLocalizedString(@"Retrieving conferences list", nil)];
	[self writeLine:@"killsc"];
	[self readAndScanForMainPrompt:&endOfFile];	
	[self writeLine:@"run showallla"];
	[self readAndScanForMainPrompt:&endOfFile];	

	// Gobble up the incoming stream.
	int lastTimeout = [socket setTimeout:2];
	[self writeLine:@"show scratchpad"];
	NSString * line = [self readLine:&endOfFile];
	while (!endOfFile)
	{
		NSString * trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSScanner * scanner = [NSScanner scannerWithString:trimmedLine];
		if ([line hasPrefix:@"o "] || [line hasPrefix:@"c "])
		{
			NSString * statusString;
			NSString * name;
			NSString * description;
			NSString * datePart;

			[scanner scanUpToString:@" " intoString:&statusString];
			[scanner scanString:@" " intoString:nil];
			[scanner scanUpToString:@" " intoString:&name];
			[scanner scanString:@" " intoString:nil];
			[scanner scanUpToString:@"" intoString:&description];

			// Extract the last word from the description. This will be
			// the date of the last access or "Closed" if the conference is
			// closed.
			NSRange range = [description rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSBackwardsSearch];
			int length = [description length];
			if (range.location != NSNotFound)
			{
				datePart = [description substringWithRange:NSMakeRange(range.location + 1, (length - range.location) - 1)];
				description = [description substringWithRange:NSMakeRange(0, range.location)];
			}
			else
			{
				datePart = description;
				description = @"";
			}
			
			NSDate * lastActiveDate;
			int status;
			if ([datePart isEqualToString:@"NoTopics"])
			{
				// For closed conferences we'll probably get the last active date IF we're a member
				// of that conference but, for now, just go with a dummy date.
				lastActiveDate = [NSDate distantFuture];
				status = MA_Empty_Conference;
			}
			else if ([statusString isEqualToString:@"o"])
			{
				lastActiveDate = [NSCalendarDate dateWithString:datePart calendarFormat:@"%d/%m/%Y"];
				status = MA_Open_Conference;
			}
			else
			{
				// For closed conferences we'll probably get the last active date IF we're a member
				// of that conference but, for now, just go with a dummy date.
				lastActiveDate = [NSDate distantFuture];
				status = MA_Closed_Conference;
			}

			// Add this conference to the database as a forum.
			Forum * forum = [[Forum alloc] initWithName:name];
			[forum setDescription:description];
			[forum setLastActiveDate:lastActiveDate];
			[forum setStatus:status];
			[forum setCategoryId:categoryId];
			[self performSelectorOnMainThread:@selector(addRetrievedForum:) withObject:forum waitUntilDone:YES];
			[forum release];

			// Show running count for actual conferences (not comments)
			if ((++count % 100) == 0)
			{
				NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Retrieving conferences list: %u items", nil), count];
				[self sendStatusToDelegate:statusString];
			}
		}
		else if (![line hasPrefix:@"-"])
		{
			NSString * rootCategory = nil;
			NSString * subCategory = nil;
			
			[scanner scanUpToString:@":" intoString:&rootCategory];
			[scanner scanString:@": " intoString:nil];
			[scanner scanUpToString:@"" intoString:&subCategory];
			
			// Create a fully qualified forum path from the category and sub-Category
			Category * category = [[Category alloc] initWithName:rootCategory];
			[category setParentId:-1];
			[self performSelectorOnMainThread:@selector(addCategory:) withObject:category waitUntilDone:YES];
			categoryId = [category categoryId];
			[category release];

			// There may not always be a sub-category...
			if (subCategory != nil)
			{
				category = [[Category alloc] initWithName:subCategory];
				[category setParentId:categoryId];
				[self performSelectorOnMainThread:@selector(addCategory:) withObject:category waitUntilDone:YES];
				categoryId = [category categoryId];
				[category release];
			}
		}
		line = [self readLine:&endOfFile];
	}
	[socket setTimeout:lastTimeout];

	// Send a nil forum to force a notification to be sent
	[self performSelectorOnMainThread:@selector(addRetrievedForum:) withObject:nil waitUntilDone:NO];
	
	// Blow away the scratchpad if everything went fine
	[self writeLine:@"killsc"];
	[self readAndScanForMainPrompt:&endOfFile];	
	[task setResultCode:MA_TaskResult_Succeeded];
}

/* resignFolder
 * Handle the task to resign a conference or topic.
 */
-(void)resignFolder:(VTask *)task
{
	NSString * folderName = [task folderName];
	BOOL endOfFile;
	int match;

	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Resigning from '%@'", nil), folderName];
	[self sendStatusToDelegate:statusString];

	// Do the resign
	[self writeStringWithFormat:YES string:@"resi %@\n", folderName];
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"M:", @"You are not", @"No topic", nil] endOfFile:&endOfFile];
	if (match == 1 || match == 2)
	{
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultStringWithFormat:NSLocalizedString(@"You were not a member of %@", nil), folderName];
	}
	else
		[task setResultCode:MA_TaskResult_Succeeded];
}

/* joinFolder
 * Join a conference or a topic within a conference
 */
-(void)joinFolder:(VTask *)task
{
	NSString * folderName = [task folderName];
	
	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Joining '%@'", nil), folderName];
	[self sendStatusToDelegate:statusString];
	
	// Now join the topic or conference
	if ([self enterFolder:task])
	{
		BOOL endOfFile;

		[self writeLine:@"quit"];
		[self readAndScanForMainPrompt:&endOfFile];
		
		// Collect the new conference statistics
		if (![folderName hasCharacter:'/'])
			[self getConferenceInfo:task];
		[task setResultCode:MA_TaskResult_Succeeded];
	}
}

/* enterFolder
 * Joins the folder specified by the task folder name. If we're not a member of the conference or
 * topic, we handle taking care of joining and responding to any errors. If we succeed, we stay in
 * the topic and return YES. If we failed, we return to the main prompt and return NO.
 */
-(BOOL)enterFolder:(VTask *)task
{
	NSString * folderName = [task folderName];
	BOOL success;
	BOOL endOfFile;
	int match;

	[self writeStringWithFormat:YES string:@"join %@\n", folderName];
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"No conference", @"Couldn't find topic", @"Topic? ", @"register  (y/n)?", @"Rf:", @"is closed", nil] endOfFile:&endOfFile];
	if (match == 0)
	{
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString:NSLocalizedString(@"No such conference", nil)];
		[self readAndScanForMainPrompt:&endOfFile];
		success = NO;
	}
	else if (match == 1)
	{
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString:NSLocalizedString(@"No such topic", nil)];
		[self writeLine:@"quit"];
		[self readAndScanForMainPrompt:&endOfFile];
		success = NO;
	}
	else if (match == 4)
	{
		success = YES;
	}
	else if (match == 5)
	{
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString:NSLocalizedString(@"Conference is closed", nil)];
		[self readAndScanForMainPrompt:&endOfFile];
		success = NO;
	}
	else if (match == 2 || match == 3)
	{
		[self writeLine:@""];
		if ([self readAndScanForStrings:[NSArray arrayWithObjects:@"M:", @"Rf:", @"Topic? ", nil] endOfFile:&endOfFile] != 0)
			success = YES;
		else
		{
			[task setResultCode:MA_TaskResult_Failed];
			[task setResultString:NSLocalizedString(@"No such topic", nil)];
			success = NO;
		}
	}
	else
		success = NO;
	return success;
}

/* getConferenceInfo
 * Retrieve the list of topics in a conference and update the database
 * with the descriptions.
 */
-(void)getConferenceInfo:(VTask *)task
{
	NSString * folderName = [task folderName];
	BOOL endOfFile;

	[self writeStringWithFormat:YES string:@"sh %@\n", folderName];
	NSString * line = [self readLine:&endOfFile];
	while (!endOfFile)
	{
		if ([line hasPrefix:@"--------------"])
		{
			line = [self readLine:&endOfFile];
			break;
		}
		line = [self readLine:&endOfFile];
	}
	while (!endOfFile)
	{
		if ([line isEqualToString:@"\n"])
			break;
		NSScanner * scanner = [NSScanner scannerWithString:line];
		NSString * topicName = nil;
		NSString * topicDescription = nil;

		// Parse the line into <topicname><spaces><description><newline>
		[scanner scanUpToString:@" " intoString:&topicName];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		[scanner scanUpToString:@"\n" intoString:&topicDescription];

		// Store in database here
		if (topicName != nil && topicDescription != nil)
		{
			CIXFolderUpdateData threadData;
			threadData.folderPath = [NSString stringWithFormat:@"%@/%@", folderName, topicName];
			threadData.description = topicDescription;
			[self performSelectorOnMainThread:@selector(updateFolder:)
								   withObject:[NSData dataWithBytes:&threadData length:sizeof(threadData)]
								waitUntilDone:YES];
		}

		// Now the next line
		line = [self readLine:&endOfFile];
	}
	[self readAndScanForMainPrompt:&endOfFile];
}

/* putResume
 * Upload the current logged in person's profile.
 */
-(void)putResume:(VTask *)task
{
	BOOL endOfFile;

	// Tell the user what we're up to
	[self sendStatusToDelegate:NSLocalizedString(@"Updating online profile", nil)];

	// Make sure the scratchpad is empty.
	[self writeLine:@"killsc"];
	[self readAndScanForMainPrompt:&endOfFile];

	// Enter edit mode
	[self writeLine:@"edit"];
	if ([self readAndScanForStrings:[NSArray arrayWithObjects:@"input->", nil] endOfFile:&endOfFile] == 0)
	{
		NSArray * wrappedText = [[task actionData] rewrapString:74];
		unsigned int wrapLineIndex = 0;
		
		while (wrapLineIndex < [wrappedText count])
		{
			NSString * line = [wrappedText objectAtIndex:wrapLineIndex];
			if ([line isEqualToString:@"."])
				line = [line stringByAppendingString:@" "];
			// DJE replaced
			// [self writeLineUsingEncoding:line encoding:NSISOLatin1StringEncoding];
			[self writeLineUsingEncoding:line encoding:NSWindowsCP1252StringEncoding];
			[self readAndScanForStrings:[NSArray arrayWithObjects:@"input->", nil] endOfFile:&endOfFile];
			++wrapLineIndex;
		}
		[self writeLine:@"."];
		[self readAndScanForStrings:[NSArray arrayWithObjects:@"Command->", nil] endOfFile:&endOfFile];
		[self writeLine:@"x"];
		[self readAndScanForMainPrompt:&endOfFile];
		[self writeLine:@"scput resume"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
	[task setResultCode:MA_TaskResult_Succeeded];
}

/* getResume
 * Retrieve a resume and store it in the database.
 */
-(void)getResume:(VTask *)task
{
	BOOL endOfFile;

	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Retrieving resume for '%@'", nil), [task actionData]];
	[self sendStatusToDelegate:statusString];

	// Collect the resume
	[self writeStringWithFormat:YES string:@"sh res %@\n", [task actionData]];

	int lastTimeout = [socket setTimeout:2];
	NSString * line = [self readLine:&endOfFile];

	// Make sure this is a valid resume. Valid CIX resumes always start with the
	// person's name and last-on date. We content ourselves with just checking for
	// the usual failure string.
	if ([line hasPrefix:@"No resume for"])
	{
		[self readAndScanForMainPrompt:&endOfFile];
		[task setResultCode:MA_TaskResult_Failed];
		[task setResultString:line];
	}
	else
	{
		NSMutableString * resumeText = [[NSMutableString alloc] init];
		while (!endOfFile)
		{
			[resumeText appendString:line];
			line = [self readLine:&endOfFile];
		}
		
		// Save the resume to the database
		[self performSelectorOnMainThread:@selector(addRetrievedResume:) withObject:resumeText waitUntilDone:NO];
		[resumeText release];

		// Mark the task as having succeeded
		[task setResultCode:MA_TaskResult_Succeeded];
	}
	[socket setTimeout:lastTimeout];
}

/* setCIXBack
 * Skip back a specified number of days
 */
-(void)setCIXBack:(VTask *)task
{
	int taskResult = MA_TaskResult_Failed;

	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Setting CIX back in %@ days", nil), [task actionData]];
	[self sendStatusToDelegate:statusString];

	[self writeLine: @"opt timeout 5 quit"];
	// DJE - hea skip back n leads to thousands of broken messages. Delete the hea
	// [self writeStringWithFormat:YES string:@"macro pjc hea skip to back %@ tnext pjc\n", [task actionData]];
	// replace with
	[self writeStringWithFormat:YES string:@"macro pjc skip to back %@ tnext pjc\n", [task actionData]];

	if ([self enterFolder:task])
	{
		int lastTimeout = [socket setTimeout:5];

		[self writeLine: @"file pjc"];
		[self collectScratchpad];
		
		[socket setTimeout:lastTimeout];
		
		taskResult = MA_TaskResult_Succeeded;
	}
	// Set the task result
	[task setResultCode:taskResult];
	[task setResultString:@"OK"];
}
/* skipBack
 * Skip back a specified number of messages
 */
-(void)skipBack:(VTask *)task
{
	BOOL endOfFile;

	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Skipping back in '%@'", nil), [task folderName]];
	[self sendStatusToDelegate:statusString];
	
	// Go into the topic
	// Now join the topic or conference
	if ([self enterFolder:task])
	{
		int taskResult = MA_TaskResult_Succeeded;
		NSString * taskData = @"";

		// Do the skip. This generally doesn't fail in a meaningful way
		int skipCount = [[task actionData] intValue];
		// dje - hea skip back leads to corrupt messages - or does it. Backout the changes
		[self writeStringWithFormat:YES string:@"hea skip to back %d\n", skipCount];
		[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];

		// Done. Now exit from the topic.
		[self writeLine:@"quit"];
		[self readAndScanForMainPrompt:&endOfFile];
		
		// Set the task result
		[task setResultCode:taskResult];
		[task setResultString:taskData];
	}
}

/* withdrawMessage
 * Withdraw a single message from a topic.
 */
-(void)withdrawMessage:(VTask *)task
{
	NSString * folderName = [task folderName];
	int messageNumber = [[task actionData] intValue];
	BOOL endOfFile;
	
	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Withdrawing message %d from '%@'", nil), messageNumber, folderName];
	[self sendStatusToDelegate:statusString];
	
	// Go into the topic
	// Now join the topic or conference
	if ([self enterFolder:task])
	{
		NSString * taskData = @"";
		int taskResult;
		int match;

		[self writeStringWithFormat:YES string:@"withdraw %d\n", messageNumber];
		if ((match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", @"You did not", @"No such message", nil] endOfFile:&endOfFile]) == 0)
			taskResult = MA_TaskResult_Succeeded;
		else if (match == 1)
		{
			taskResult = MA_TaskResult_Failed;
			taskData = [taskData stringByAppendingFormat:NSLocalizedString(@"You did not originate %d\n", nil), messageNumber];
		}
		else
		{
			taskResult = MA_TaskResult_Failed;
			taskData = [taskData stringByAppendingFormat:NSLocalizedString(@"No such message %d\n", nil), messageNumber];
		}

		// Done. Now exit from the topic.
		[self writeLine:@"quit"];
		[self readAndScanForMainPrompt:&endOfFile];

		// Set the task result
		[task setResultCode:taskResult];
		[task setResultString:taskData];
	}
}

/* fileMessages
 * Retrieve a range of messages from a topic.
 */
-(void)fileMessages:(VTask *)task
{
	NSString * folderName = [task folderName];
	BOOL endOfFile;
	
	// Tell the user what we're up to
	NSString * statusString = [NSString stringWithFormat:NSLocalizedString(@"Retrieving messages from '%@'", nil), folderName];
	[self sendStatusToDelegate:statusString];

	// Go into the topic
	// Now join the topic or conference
	if ([self enterFolder:task])
	{
		NSString * taskData;
		int taskResult;

		// Assume we'll succeed
		taskData = @"";
		taskResult = MA_TaskResult_Succeeded;
		
		// actionData is an ordered list of messages to retrieve. It may be one message
		// or several messages delimited by a non-numeric character, or a range delimited
		// by a - character.
		NSScanner * scanner = [NSScanner scannerWithString:[task actionData]];
		while (![scanner isAtEnd])
		{
			NSString * rangeString;
			int firstNumber;
			int lastNumber;

			[scanner scanInt:&firstNumber];
			if (![scanner scanString:@"-" intoString:nil])
				rangeString = [NSString stringWithFormat:@"file %d", firstNumber];
			else
			{
				[scanner scanInt:&lastNumber];
				rangeString = [NSString stringWithFormat:@"file %d to %d", firstNumber, lastNumber];
			}
			[self writeLine:rangeString];
			if ([self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", @"No such message", nil] endOfFile:&endOfFile] == 1)
			{
				taskResult = MA_TaskResult_Failed;
				taskData = [taskData stringByAppendingFormat:NSLocalizedString(@"No message %d\n", nil), firstNumber];
			}
			[scanner scanString:@"," intoString:nil];
		}
		
		// Done. Now exit from the topic and we'll pick up the messages when
		// we do the 'file read all'.
		[self writeLine:@"quit"];
		[self readAndScanForMainPrompt:&endOfFile];
		
		// Now collect the messages
		int lastTimeout = [socket setTimeout:2];
		[self collectScratchpad];
		[socket setTimeout:lastTimeout];

		// Set the task result
		[task setResultCode:taskResult];
		[task setResultString:taskData];
	}
}

-(BOOL)hasHighBitChars:(NSMutableArray *)text
{
	unsigned int index, charindex;
	
	for (index = 0; index < [text count]; ++index)
	{
		NSString *line = [text objectAtIndex:index];
		for (charindex=0; charindex<[line length]; charindex++) 
		{
			if ([line characterAtIndex:charindex] > 127)
				return YES;
		}
	}
	return NO;
}

/* postMessages
 * Post all messages in the outbox
 */
-(void)postMessages:(VTask *)task
{
	NSEnumerator * enumerator = [messagesToPost objectEnumerator];
	VMessage * message;
	NSString * taskData;
	int taskResult;
	BOOL needStore;
	BOOL endOfFile;
	BOOL isInTopic;

	// Initialize
	isInTopic = NO;
	needStore = YES;
	taskResult = MA_TaskResult_Succeeded;
	taskData = @"";
	
	// Loop for every message
	while ((message = [enumerator nextObject]) != nil)
	{
		int match;

		// If we need to checkpoint, do it now.
		// Why? Because on CIX, posting a message advances us past that message so we
		// end up not getting a copy of the message into the scratchpad. The fix is to
		// save our message pointers before we start posting and then restore them
		// afterwards.
		if (needStore)
		{
			[self writeLine:@"checkpoint"];
			[self readAndScanForMainPrompt:&endOfFile];
			[self writeLine:@"store"];
			[self readAndScanForMainPrompt:&endOfFile];
			[self writeLine:@"killsc"];
			[self readAndScanForMainPrompt:&endOfFile];
			needStore = NO;
		}
		
		// Join the topic.
		// Handle the case where the topic is not present
		[self writeStringWithFormat:YES string:@"j %@\n", [message sender]];
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", @"No conference", nil] endOfFile:&endOfFile];
		if (match == 1)
		{
			taskData = [taskData stringByAppendingFormat:NSLocalizedString(@"No conference '%@'\n", nil), [message sender]];
			taskResult = MA_TaskResult_Failed;
		}
		else
		{
			BOOL okayToPost = NO;
			isInTopic = YES;

			// Rewrap the text so we break at column 74
			NSMutableArray * wrappedMessageBody = [[message text] rewrapString:74];
			unsigned int countOfWrappedLines = [wrappedMessageBody count];
			NSString * firstLineOfMessage = countOfWrappedLines ? [wrappedMessageBody objectAtIndex:0] : @"";
			unsigned int wrapLineIndex = 0;

			NSString * sendString = [NSString stringWithFormat:NSLocalizedString(@"Posting '%@'", nil), firstLineOfMessage];
			[self sendStatusToDelegate:sendString];

			// Check for entirely blank bodies
			unsigned int index;
			for (index = 0; index < countOfWrappedLines; ++index)
			{
				NSString * line = [wrappedMessageBody objectAtIndex:wrapLineIndex];
				if (![line isEqualToString:@""])
					break;
			}
			if (index == countOfWrappedLines)
			{
				[wrappedMessageBody addObject:@" "];
				++countOfWrappedLines;
			}

			// If the message has non-ASCII characters then send it via zmodem
			// to preserve the top bit.
			if ([self hasHighBitChars: wrappedMessageBody])
			{
				NSString *tempFilename = @"/private/tmp/ViennaUpload.txt";

				// Write file and upload using Zmodem.
				if (![[NSFileManager defaultManager] createFileAtPath:tempFilename contents:nil attributes:nil])
				{
					NSLog(@"Cannot create file %@ for upload\n", tempFilename);
					continue;
				}
				NSFileHandle * fileHandle = [NSFileHandle fileHandleForWritingAtPath:tempFilename];
				
				// Write initial commands to join and create message
				NSString *header1 = [NSString stringWithFormat:@"join %@\n", [message sender]];
				NSString *header2;
				// DJE replaced
				//NSData *header = [header1 dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
				NSData *header = [header1 dataUsingEncoding:NSWindowsCP1252StringEncoding allowLossyConversion:YES];

				[fileHandle writeData: header];
				
				if ([message comment])
				{
					header2 = [NSString stringWithFormat:@"comment %d\n", [message comment]];
				}
				else
				{
					header2 = @"say\n";
				}
				// DJE replaced
				//header = [header2 dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
				header = [header2 dataUsingEncoding:NSWindowsCP1252StringEncoding allowLossyConversion:YES];

				[fileHandle writeData: header];

				// Now send the message
				NSData *nl = [NSData dataWithBytes: "\n" length:1];
				NSData *eof = [NSData dataWithBytes: ".\n" length:2];
				for (index = 0; index < countOfWrappedLines; ++index)
				{
					NSString *line = [wrappedMessageBody objectAtIndex:index];
					// DJE replaced
					//NSData * msgData = [line dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
					NSData * msgData = [line dataUsingEncoding:NSWindowsCP1252StringEncoding allowLossyConversion:YES];

					[fileHandle writeData:msgData];
					[fileHandle writeData:nl];
				}
				[fileHandle writeData:eof];
				[fileHandle closeFile];
				
				// Send to scratchpad using zModem
				[self writeLine:@"upl"];
				if ([self zmodemSend: tempFilename] == 0)
				{
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Scratchpad is", nil] endOfFile:&endOfFile];
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
					[self writeLine:@"scput script"];
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
					[self writeLine:@"script"];
					[self readAndScanForMainPrompt:&endOfFile];
				}
				else
				{
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
				}
				
				// Remove file
				[[NSFileManager defaultManager] removeFileAtPath: tempFilename handler:nil];

				// If we succeded, delete this message from the Outbox
				[self performSelectorOnMainThread:@selector(markMessagePosted:) withObject:message waitUntilDone:NO];

				continue;
			}
			
			// Do a SAY or COMMENT as appropriate
			if ([message comment] == 0)
			{
				[self writeLine:@"edit"];
				match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"input->", @"Read-Only topic.", nil] endOfFile:&endOfFile];
				if (match == 1)
				{
					taskData = [taskData stringByAppendingFormat:@"Topic '%@' is read-only\n", [message sender]];
					taskResult = MA_TaskResult_Failed;
				}
				else
				{
					while (wrapLineIndex < countOfWrappedLines)
					{
						NSString * line = [wrappedMessageBody objectAtIndex:wrapLineIndex];
						if ([line isEqualToString:@"."])
							line = [line stringByAppendingString:@" "];
						// DJE Replaced
						// [self writeLineUsingEncoding:line encoding:NSISOLatin1StringEncoding];
						[self writeLineUsingEncoding:line encoding:NSWindowsCP1252StringEncoding];

						[self readAndScanForStrings:[NSArray arrayWithObjects:@"input->", nil] endOfFile:&endOfFile];
						++wrapLineIndex;
					}
					
					// The rest of the torturous process of doing a SAY without gettting a 
					// TITLE line.
					[self writeLine:@"."];
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Command->", nil] endOfFile:&endOfFile];
					[self writeLine:@"x"];
					[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
					[self writeLine:@"say"];
					
					match =  [self readAndScanForStrings:[NSArray arrayWithObjects:@"Command->", @"Read-Only topic.", nil] endOfFile:&endOfFile];
					if (match == 1)
					{
						taskData = [taskData stringByAppendingFormat:@"Topic '%@' is read-only\n", [message sender]];
						taskResult = MA_TaskResult_Failed;
					}
					else
					{
						[self writeLine:@"x"];
						okayToPost = YES;
					}
				}
			}
			else
			{
				[self writeStringWithFormat:YES string:@"comment %d\n", [message comment]];
				match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"'.<CR>'", @"Read-Only topic.", nil] endOfFile:&endOfFile];
				if (match == 1)
				{
					taskData = [taskData stringByAppendingFormat:NSLocalizedString(@"Topic '%@' is read-only\n", nil), [message sender]];
					taskResult = MA_TaskResult_Failed;
				}
				else
				{
					// Send the body text divided up into 78 character chunks.
					// Note the check for line equals ".". The dot character on its own terminates
					// the edit session so if it occurs in the body of some text, we append a space
					// to ensure that we don't mislead the text gobbler.
					while (wrapLineIndex < countOfWrappedLines)
					{
						NSString * line = [wrappedMessageBody objectAtIndex:wrapLineIndex];
						if ([line isEqualToString:@"."])
							line = [line stringByAppendingString:@" "];
						// DJE replaced
						// [self writeLineUsingEncoding:line encoding:NSISOLatin1StringEncoding];
						[self writeLineUsingEncoding:line encoding:NSWindowsCP1252StringEncoding];
						++wrapLineIndex;
					}
					[self writeLine:@"."];
					okayToPost = YES;
				}
			}

			// Post the message
			if (okayToPost)
			{
				[self readAndScanForStrings:[NSArray arrayWithObjects:@"A:", nil] endOfFile:&endOfFile];
				[self writeLine:@"add"];
				[self readAndScanForStrings:[NSArray arrayWithObjects:@"Rf:", nil] endOfFile:&endOfFile];
				
				// If we succeded, delete this message from the Outbox
				[self performSelectorOnMainThread:@selector(markMessagePosted:) withObject:message waitUntilDone:NO];
			}
		}
	}

	// Exit from posting in topics back to the main prompt
	if (isInTopic)
	{
		[self writeLine:@"q"];
		[self readAndScanForMainPrompt:&endOfFile];
	}
	
	// Restore our message pointers back to the point before we
	// started posting.
	if (!needStore)
	{
		[self writeLine:@"restore"];
		[self readAndScanForMainPrompt:&endOfFile];
	}

	// Set the task result
	[task setResultCode:taskResult];
	[task setResultString:taskData];
}

/* connectToService
 * Open a socket and connect to the service. Perform the initial
 * authentication and login protocol.
 */
-(int)connectToService
{
	BOOL endOfFile;
	int match;

	// Current connection types are only 0=telnet, 1=SSH
	usingSSH = [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_ConnectionType];
	
	cixAbortFlag = NO;

	if (usingSSH)
	{
		[self sendStatusToDelegate:NSLocalizedString(@"Connecting to service using SSH", nil)];
		socket = [[SSHSocket alloc] initWithAddress:@"cix.compulink.co.uk" port:22];		
	}
	else
	{
		[self sendStatusToDelegate:NSLocalizedString(@"Connecting to service using telnet", nil)];
		socket = [[TCPSocket alloc] initWithAddress:@"cix.compulink.co.uk" port:23];
	}
	
	if (![socket connect])
		return MA_Connect_ServiceUnavailable;

	// Initialise log file
	int logVersions = [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_LogVersions];
	if (logVersions)
		[socket setLogFile: @"connect" versions: logVersions];

	if (!usingSSH)
	{
		// Negotiate the telnet protocol sequence
		[socket sendBytes:"\xFF\xFD\x00" length:3];		// SENT BINARY
		[socket sendBytes:"\xFF\xFB\x18" length:3];		// SENT WILL TERMTYPE
		[socket sendBytes:"\xFF\xFC\x03" length:3];		// SENT WON'T SUPPRESS GO-AHEAD
		[socket sendBytes:"\xFF\xFC\x22" length:3];		// SENT WON'T LINEMODE
		[socket sendBytes:"\xFF\xFE\x01" length:3];		// SENT DON'T ECHO

		// Unix Login telnet only 
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"ogin: ", nil] endOfFile:&endOfFile];
		if (endOfFile)
			return MA_Connect_Aborted;

		[self writeLine:@"qix"];
	}
	
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"user) ", @"with nodename", nil] endOfFile:&endOfFile];
	if (endOfFile || match == 1)
		return MA_Connect_Aborted;
	
	// Send username
	[self sendStatusToDelegate:[NSString stringWithFormat:NSLocalizedString(@"Logging in as user %@", nil), [self username]]];
	[self writeLine:[self username]];
	match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"word: ", @"user) ", nil] endOfFile:&endOfFile];
	if (match == 1)
		return MA_Connect_BadUsername;
	if (endOfFile)
		return MA_Connect_Aborted;

	// Send password and handle illegal password condition
	[self sendStatusToDelegate:NSLocalizedString(@"Sending password", nil)];
	[self writeStringWithFormat:NO string:@"%@\n", [self password]];
	while (YES)
	{
		match = [self readAndScanForStrings:[NSArray arrayWithObjects:@"word: ", @"(N/y)?", @"More ?", @"M:", @"Main:", nil] endOfFile:&endOfFile];
		if (match == 0)
			return MA_Connect_BadPassword;
		if (match == 1)
			return MA_Connect_AlreadyConnected;
		if (match == 2)
		{
			[self writeLine:@""];
			continue;
		}
		break;
	}
	if (endOfFile)
		return MA_Connect_Aborted;

	// Make sure we're in a consistent state for all users:
	// - Compact header format on messages
	// - Terse output (M: instead of Main:, etc)
	// - No paging in terminal
	int recentCount = [[NSUserDefaults standardUserDefaults] integerForKey:MAPref_RecentOnJoin];

	[self writeStringWithFormat:YES string:@"opt missing y terse comp y ref y term pag 0 term width 300 edit v bit8 y recent %d u z d z q\n", recentCount];
	[self readAndScanForMainPrompt:&endOfFile];
	if (endOfFile)
		return MA_Connect_Aborted;
	
	// Set a zero timeout if we're in online mode
	if (online)
	{
		NSString * line;

		// Check CIX account type and disable online mode if the account is not a flat
		// fee type (i.e. charged per minute). Online mode can be expensive for these
		// folks.
		[self writeLine:@"go acctype"];
		line = [self readLine:&endOfFile];
		if (!endOfFile && ([line hasPrefix:@"ICA-OUT"] || [line hasPrefix:@"OUT"]))
			online = NO;
		else
		{
			[self writeLine:@"opt timeout 0 q"];
			[self readAndScanForMainPrompt:&endOfFile];
		}
		if (endOfFile)
			return MA_Connect_Aborted;
	}
	return MA_Connect_Success;
}

/* disconnectFromService
 * As its name implies, cleanly disconnect from the service.
 */
-(void)disconnectFromService
{
	if ([socket isConnected])
	{
		BOOL endOfFile;
		if (!shuttingDown)
			[self sendStatusToDelegate:NSLocalizedString(@"Disconnecting from service", nil)];
		[self writeLine:@"bye y"];
		[self readAndScanForStrings:[NSArray arrayWithObjects:@"HANGUP", nil] endOfFile:&endOfFile];
	}
}

/* writeLine
 * Writes a string followed by a newline to the service and then waits for that
 * string to be echoed back.
 */
-(BOOL)writeLine:(NSString *)string
{
	return [self writeStringWithFormat:YES string:@"%@\n", string];
}

/* writeLineUsingEncoding
 */
-(BOOL)writeLineUsingEncoding:(NSString *)string encoding:(NSStringEncoding)encoding
{
	NSData * msgData = [string dataUsingEncoding:encoding allowLossyConversion:YES];
	if ([socket sendBytes:[msgData bytes] length:[msgData length]])
	{
		if ([socket sendBytes:"\n" length:1])
			return YES;
	}
	return NO;
}

/* writeStringWithFormat
 * Formats a string with arguments and writes that string to the service.Then
 * if echo is YES, we wait for that string to be echoed back.
 */
-(BOOL)writeStringWithFormat:(BOOL)echo string:(NSString *)string, ...
{
	NSString * formattedString;
	va_list arguments;
	BOOL result;

	va_start(arguments, string);
	formattedString = [[NSString alloc] initWithFormat:NSLocalizedString(string, nil) arguments:arguments];
	result = [self writeString:echo string:formattedString];
	[formattedString release];
	va_end(arguments);
	return result;
}

/* writeString
 * Writes a string to the service. If echo is YES, we wait for that string to
 * be echoed back.
 */
-(BOOL)writeString:(BOOL)echo string:(NSString *)string
{
	BOOL endOfFile = NO;

	[socket sendString:string];
	if (echo)
		[self readAndScanForStrings:[NSArray arrayWithObjects:string, nil] endOfFile:&endOfFile];
	return endOfFile;
}

/* pushBackLine
 * Push back a line we got from the service so that the
 * next read will get this line instead.
 */
-(void)pushBackLine:(NSString *)line
{
	NSAssert(!isPushedLine, @"Cannot push back more than one line");
	[line retain];
	[pushedLine release];
	pushedLine = line;
	isPushedLine = YES;
}

/* readLine
 * Read one line from the service.
 */
-(NSString *)readLine:(BOOL *)endOfFile
{
	if (cixAbortFlag)
	{
		*endOfFile = YES;
		return nil;
	}
	if (isPushedLine)
	{
		isPushedLine = NO;
		return pushedLine;
	}
	NSString * string = [socket readLine:endOfFile];
	[self sendActivityStringToDelegate:string];
	return string;
}

/* readAndScanForMainPrompt
 * Scan for the M: prompt.
 */
-(void)readAndScanForMainPrompt:(BOOL *)endOfFile
{
	[self readAndScanForStrings:[NSArray arrayWithObjects:@"M:", nil] endOfFile:endOfFile];
}

/* readAndScanForStrings
 * Reads from the service until we match one of the strings in
 * the array. If we match, we return the index of the matching
 * string.
 */
-(int)readAndScanForStrings:(NSArray *)stringsToScan endOfFile:(BOOL *)endOfFile
{
	int count = [stringsToScan count];
	NSMutableArray * scanStrings = [[NSMutableArray alloc] initWithCapacity:count];
	int matchIndex = NSNotFound;
	
	// Make a copy of the array but with all
	// the strings reversed.
	int longestLength = 0;
	int c;

	for (c = 0; c < count; ++c)
	{
		NSString * reversedString = [[stringsToScan objectAtIndex:c] reversedString];
		int length;

		[scanStrings addObject:reversedString];
		if ((length = [reversedString length]) > longestLength)
			longestLength = length;
	}

	// Create a match buffer
	char * matchbuffer = malloc(sizeof(char) * (longestLength + 1));
	if (matchbuffer == nil)
		return -1;
	memset(matchbuffer, '\0', longestLength + 1);

	// Now read from the service and match the last X characters with
	// the strings in the array where X is the length of the shortest
	// string in the array.
	char linebuffer[MAX_LINE];
	int bufferindex = 0;
	char ch;

	ch = [self readServiceChar:endOfFile];
	while (!*endOfFile)
	{
		if (cixAbortFlag)
		{
			*endOfFile = YES;
			break;
		}
		if (bufferindex == MAX_LINE - 1)
		{
			linebuffer[bufferindex] = '\0';
			// deprecated API was here DJE
			[self sendActivityStringToDelegate:[NSString stringWithCString:linebuffer
																  encoding:NSWindowsCP1252StringEncoding]];
			bufferindex = 0;
		}
		if (ch != '\r')
		{
			linebuffer[bufferindex++] = ch;

			// Rotate this character into the fixed reverse window buffer
			// which we use to match against the array.
			for (c = longestLength - 1; c > 0; --c)
				matchbuffer[c] = matchbuffer[c - 1];
			matchbuffer[0] = ch;

			for (c = 0; c < count && matchIndex == NSNotFound; ++c)
			{
				const char * scanString = [[scanStrings objectAtIndex:c] cString];
				if (memcmp(matchbuffer, scanString, strlen(scanString)) == 0)
					matchIndex = c;
			}

			// Take an early exit and stop reading if we match
			if (matchIndex != NSNotFound)
				break;
		}
		ch = [self readServiceChar:endOfFile];
	}
	linebuffer[bufferindex] = '\0';
	// deprecated API was here DJE
	[self sendActivityStringToDelegate:[NSString stringWithCString:linebuffer
														  encoding:NSWindowsCP1252StringEncoding]];
	
	// Exit
	free(matchbuffer);
	[scanStrings release];
	return matchIndex;
}

// Telnet state machine
enum {
	TSTATE_BEGIN,
	TSTATE_IAC,
	TSTATE_DO,
	TSTATE_WILL,
	TSTATE_WONT,
	TSTATE_DONT,
	TSTATE_SB,
	TSTATE_SB_ACTION,
	TSTATE_DONE
};

// Telnet codes
#define TERMTYPE	24
#define BINARY		0
#define IAC			255
#define DONT		254
#define DO			253
#define WONT		252
#define WILL		251
#define SE			240
#define SB			250

/* readServiceChar
 * This is a wrapper over the socket readChar that embodies additional logic
 * for handling Telnet control codes.
 */
-(char)readServiceChar:(BOOL *)endOfFile
{
	int state;
	int optcode;
	int optaction;
	unsigned char ch;
	
	if (usingSSH)
	{
		return ch = [socket readChar:endOfFile];
	}

	state = TSTATE_BEGIN;
	optcode = 0;
	optaction = 0;
	ch = [socket readChar:endOfFile];
	while (!*endOfFile)
	{
		char response[4];
		switch (state)
		{
			case TSTATE_BEGIN:
				state = (ch == IAC) ? TSTATE_IAC : TSTATE_DONE;
				break;

			case TSTATE_SB:
				optcode = ch;
				state = TSTATE_SB_ACTION;
				break;

			case TSTATE_SB_ACTION:
				optaction = ch;
				state = TSTATE_BEGIN;
				break;
				
			case TSTATE_IAC:
				if (ch == DONT)
					state = TSTATE_DONT;
				else if (ch == DO)
					state = TSTATE_DO;
				else if (ch == WONT)
					state = TSTATE_WONT;
				else if (ch == WILL)
					state = TSTATE_WILL;
				else if (ch == SB)
					state = TSTATE_SB;
				else if (ch == SE)
				{
					if (optcode == TERMTYPE && optaction == 1)
					{
						response[0] = IAC;
						response[1] = SB;
						response[2] = TERMTYPE;
						response[3] = 0;
						[socket sendBytes:response length:4];
						[socket sendBytes:"ANSI" length:4];
						response[0] = IAC;
						response[1] = SE;
						[socket sendBytes:response length:2];
					}
					optcode = 0;
					optaction = 0;
				}
				else
					state = TSTATE_DONE;
				break;

			case TSTATE_DO:
				if (ch == TERMTYPE || ch == BINARY)
				{
					response[0] = IAC;
					response[1] = WILL;
					response[2] = ch;
				}
				else
				{
					response[0] = IAC;
					response[1] = WONT;
					response[2] = ch;
				}
				[socket sendBytes:response length:3];
				state = TSTATE_BEGIN;
				break;
				
			case TSTATE_DONT:
				response[0] = IAC;
				response[1] = WONT;
				response[2] = ch;
				[socket sendBytes:response length:3];
				state = TSTATE_BEGIN;
				break;
				
			case TSTATE_WILL:
				response[0] = IAC;
				response[1] = DO;
				response[2] = ch;
				[socket sendBytes:response length:3];
				state = TSTATE_BEGIN;
				break;
				
			case TSTATE_WONT:
				response[0] = IAC;
				response[1] = DONT;
				response[2] = ch;
				[socket sendBytes:response length:3];
				state = TSTATE_BEGIN;
				break;
		}
		if (state == TSTATE_DONE)
			break;
		ch = [socket readChar:endOfFile];
	}
	return ch;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[self disconnectFromService];
	[condLock release];
	[rssArray release];
	[tasksArray release];
	[messagesToPost release];
	[delegate release];
	[super dealloc];
}

@end
