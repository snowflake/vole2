//
//  TasksWindow.m
//  Vienna
//
//  Created by Steve on Sun Apr 11 2004.
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

#import "TasksWindow.h"
#import "CalendarExtensions.h"

@implementation TasksWindow

/* init
 * Just init the tasks window.
 */
-(id)init
{
	if ((self = [super initWithWindowNibName:@"TasksWindow"]) != nil)
	{
		db = nil;
		currentArrayOfTasks = nil;
		allowRefresh = YES;
	}
	return self;
}

/* windowDidLoad
 * Set the font for the activity viewer
 */
-(void)windowDidLoad
{
	// Refresh the tasks list
	[self refreshTasksList];

	// Get the click actions so we can handle them
	[tasksList setAction:@selector(handleClick:)];

	// Extend the last column
	[tasksList sizeLastColumnToFit];
	
	// Work around a Cocoa bug where the window positions aren't saved
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"tasksWindow"];
	
	// Register our notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTaskListChange:) name:@"MA_Notify_TaskChanged" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTaskListChange:) name:@"MA_Notify_TaskAdded" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTaskListChange:) name:@"MA_Notify_TaskDeleted" object:nil];
}

/* tableViewShouldDisplayCellToolTips
 * Called to ask whether the table view should display tooltips.
 */
-(BOOL)tableViewShouldDisplayCellToolTips:(NSTableView *)tableView
{
    (void)tableView;
	return YES;
}

/* toolTipForTableColumn
 * Return the tooltip for the specified row and column.
 */
-(NSString *)tableView:(NSTableView *)tableView toolTipForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    (void)tableColumn;
    (void)tableView;
	VTask * task = [currentArrayOfTasks objectAtIndex:rowIndex];
	return [task resultString];
}

/* setDatabase
 * Changes the database used by the tasks list then refreshes the
 * list.
 */
-(void)setDatabase:(Database *)newDb
{
	[newDb retain];
	[db release];
	db = newDb;
	[self refreshTasksList];
}

/* handleTaskListChange
 * Handle notifications from the database when the list of tasks are updated
 */
-(void)handleTaskListChange:(NSNotification *)notification
{
    (void)notification;
	if (allowRefresh)
		[self refreshTasksList];
}

/* handleClick
 * Called when the user clicks in a row
 */
-(void)handleClick:(id)sender
{
    (void)sender;
	NSInteger selectedColumn = [tasksList clickedColumn];
    if (selectedColumn < 0) return; // Column does  not exist, must be on a blank row
                                    // (DJE added to fix exception)
                                    // Fixes cix:vienna/bugs:49
	NSTableColumn * column = [[tasksList tableColumns] objectAtIndex:selectedColumn];
	NSString * identifier = [column identifier];

	if ([identifier isEqualToString:@"remove"])
		[self removeSelectedTasks:self];
	if ([identifier isEqualToString:@"reschedule"])
		[self reRunSelectedTasks:self];
}

/* refreshTasksList
 * Refreshes the task list from the database.
 */
-(void)refreshTasksList
{
	[currentArrayOfTasks release];
	currentArrayOfTasks = [[NSMutableArray arrayWithArray:[db arrayOfTasks:NO] ] retain];
	[tasksList reloadData];
	[clearButton setEnabled:[currentArrayOfTasks count] > 0];
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of rows we'll display.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    (void)aTableView;
	return [currentArrayOfTasks count];
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    (void)aTableView;
	NSString * identifier = [aTableColumn identifier];
	VTask * task = [currentArrayOfTasks objectAtIndex:rowIndex];

	// Show the icon representing the current state of the task
	if ([identifier isEqualToString:@"successFail"])
	{
		switch ([task resultCode])
		{
		case MA_TaskResult_Failed:
			return [NSImage imageNamed:@"taskFailed.tiff"];

		case MA_TaskResult_Succeeded:
			return [NSImage imageNamed:@"taskSucceeded.tiff"];

		case MA_TaskResult_Running:
			return [NSImage imageNamed:@"taskRunning.tiff"];
		}
		return [NSImage imageNamed:@"alpha.tiff"];
	}

	// Show the grey icon that reschedules the selected task to run again
	if ([identifier isEqualToString:@"reschedule"])
		return [NSImage imageNamed:@"reschedule_grey.tiff"];

	// Show the grey icon that deletes the selected tasks
	if ([identifier isEqualToString:@"remove"])
		return [NSImage imageNamed:@"remove_grey.tiff"];

	if ([identifier isEqualToString:@"description"])
	{
		NSString * taskName;
		switch ([task actionCode])
		{
			case MA_TaskCode_PostMessages:		taskName = NSLocalizedString(@"Post messages", nil); break;
			case MA_TaskCode_ReadMessages:		taskName = NSLocalizedString(@"Read new messages", nil); break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ResignFolder:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Resign from %@", nil), [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_JoinFolder:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Join %@", nil), [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_WithdrawMessage:   taskName = [NSString stringWithFormat:NSLocalizedString(@"Withdraw message %@ from %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_FileMessages:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Retrieve message(s) %@ from %@", nil), [task actionData], [task folderName]]; break;
			case MA_TaskCode_ConfList:			taskName = NSLocalizedString(@"Refresh browser list", nil); break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_SkipBack:			taskName = [NSString stringWithFormat:NSLocalizedString(@"Skip back %@ messages in %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_SetCIXBack:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Set CIX back %@ day(s)", nil), [task actionData]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_GetResume:			taskName = [NSString stringWithFormat:NSLocalizedString(@"Get profile for '%@'", nil), [task actionData]]; break;
			case MA_TaskCode_PutResume:			taskName = NSLocalizedString(@"Update your online profile", nil); break;
			case MA_TaskCode_GetRSS:			taskName = NSLocalizedString(@"Refresh RSS feeds", nil); break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_FileDownload:      taskName = [NSString stringWithFormat:NSLocalizedString(@"Download file %@ from %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_FileUpload:        taskName = [NSString stringWithFormat:NSLocalizedString(@"Upload file %@ to %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModAddPart:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Add particpant %@ to %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModRemPart:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Remove participant %@ from %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModComod:			taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Comod %@ to %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModExmod:			taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Exmod %@ from %@", nil), [task actionData], [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModRdOnly:			taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Make %@ readonly", nil), [task folderName]]; break;
// #warning 64BIT: Check formatting arguments
			case MA_TaskCode_ModNewConf:		taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod New conference %@", nil), [task folderName]]; break;
			case MA_TaskCode_ModAddTopic:		
				{
					// The conf name is partly in the foldername and partly in taskData, because folderName needs to point to an existing
					// topic so we can "join" it.
					NSArray *folderBits = [[task folderName] pathComponents];
					NSArray *dataBits = [[task actionData] componentsSeparatedByString:@":"];
					NSString *confName = [NSString stringWithFormat:@"%@/%@", [folderBits objectAtIndex: 0], [dataBits objectAtIndex: 0]];
// #warning 64BIT: Check formatting arguments
					taskName = [NSString stringWithFormat:NSLocalizedString(@"Mod Add Topic %@", nil), confName]; 
				}
				break;
			default:							taskName = @"Unknown task"; break;
		}
		return taskName;
	}	

	// Show the result of the last run
	if ([identifier isEqualToString:@"result"])
		return [task resultString];
	
	// Show the date or status of the next run.
	if ([identifier isEqualToString:@"nextRun"])
	{
		if ([task resultCode] == MA_TaskResult_Waiting)
			return NSLocalizedString(@"Will run on next connect", nil);

		if ([task resultCode] == MA_TaskResult_Running)
			return NSLocalizedString(@"Running...", nil);

		if (![[task earliestRunDate] isEqualToDate:[NSDate distantFuture]])
		{
			NSCalendarDate * anDate = [[task earliestRunDate] dateWithCalendarFormat:nil timeZone:nil];
// #warning 64BIT: Check formatting arguments
			return [NSString stringWithFormat:NSLocalizedString(@"Will run after %@", nil), [anDate friendlyDescription]];
		}
		return @"";
	}

	// Assert if we add a new column and forget to handle it here.
	NSAssert1([identifier isEqualToString:@"lastRun"], @"Unhandled table column '%@'", identifier);

	// Show the date when the task was last run, or leave this column blank if it hasn't
	// been run yet.
	if (![[task lastRunDate] isEqualToDate:[NSDate distantFuture]])
	{
		NSCalendarDate * anDate = [[task lastRunDate] dateWithCalendarFormat:nil timeZone:nil];
// #warning 64BIT: Check formatting arguments
		return [NSString stringWithFormat:NSLocalizedString(@"Last ran %@", nil), [anDate friendlyDescription]];
	}
	return @"";
}

/* clear
 * Clear completed tasks from the list.
 */
-(IBAction)clear:(id)sender
{
    (void)sender;
	[db clearTasks:MA_TaskResult_Succeeded];
	[db clearTasks:MA_TaskResult_Failed];
}

/* removeSelectedTasks
 * Delete the selected tasks.
 */
-(IBAction)removeSelectedTasks:(id)sender
{
    (void)sender;
	NSEnumerator * enumerator = [tasksList selectedRowEnumerator];
	NSNumber * rowIndex;	

	allowRefresh = NO;
	while ((rowIndex = [enumerator nextObject]) != nil)
	{
// #warning 64BIT intValue used instead of integerValue
		VTask * task = [currentArrayOfTasks objectAtIndex:[rowIndex intValue]];
		[db deleteTask:task];
	}
	allowRefresh = YES;
	[self refreshTasksList];
}

/* reRunSelectedTasks
 * Mark the selected tasks scheduled to run on the next connect.
 */
-(IBAction)reRunSelectedTasks:(id)sender
{
    (void)sender;
	NSEnumerator * enumerator = [tasksList selectedRowEnumerator];
	NSNumber * rowIndex;	

	allowRefresh = NO;
	while ((rowIndex = [enumerator nextObject]) != nil)
	{
// #warning 64BIT DJE intValue used intrad of integerValue
		VTask * task = [currentArrayOfTasks objectAtIndex:[rowIndex intValue]];
		[db setTaskWaiting:task];
	}
	allowRefresh = YES;
	[self refreshTasksList];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[db release];
	[currentArrayOfTasks release];
	[super dealloc];
}
@end
