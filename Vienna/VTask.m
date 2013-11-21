//
//  VTask.m
//  Vienna
//
//  Created by Steve on Sun Apr 04 2004.
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

#import "VTask.h"

@implementation VTask

/* init
 * Initialise ourselves.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		[self setActionCode:MA_TaskCode_NoTask];
		[self setActionData:@""];
		[self setFolderName:@""];
		[self setResultString:@""];
		resultCode = MA_TaskResult_Waiting;
		lastRunDate = [[NSDate distantFuture] retain];
		earliestRunDate = [[NSDate distantPast] retain];
	}
	return self;
}

/* setTaskId
 * Sets the ID for this task.
 */
-(void)setTaskId:(NSInteger)newTaskId
{
	taskId = newTaskId;
}

/* taskId
 * Returns the unique task ID
 */
-(NSInteger)taskId
{
	return taskId;
}

/* setActionCode
 * Sets the action code for this task
 */
-(void)setActionCode:(NSInteger)newActionCode
{
	actionCode = newActionCode;
}

/* actionCode
 * Return the action code that identifies this task.
 */
-(NSInteger)actionCode
{
	return actionCode;
}

/* setActionData
 * Sets the action data for this task.
 */
-(void)setActionData:(NSString *)newActionData
{
	[newActionData retain];
	[actionData release];
	actionData = newActionData;
}

/* actionData
 * Return additional data associated with the action code.
 */
-(NSString *)actionData
{
	return actionData;
}

/* setFolderName
 * Sets the name of the folder associated with this task.
 */
-(void)setFolderName:(NSString *)newFolderName
{
	[newFolderName retain];
	[folderName release];
	folderName = newFolderName;
}

/* folderName
 * Returns the name of the folder associated with this task.
 */
-(NSString *)folderName
{
	return folderName;
}

/* setResultCode
 * Sets the action result code
 */
-(void)setResultCode:(NSInteger)newResultCode
{
	resultCode = newResultCode;
}

/* resultCode
 * Returns the action result code.
 */
-(NSInteger)resultCode
{
	return resultCode;
}

/* setOrderCode
 * Sets the action order code
 */
-(void)setOrderCode:(NSInteger)newOrderCode
{
	orderCode = newOrderCode;
}

/* orderCode
 * Returns the action order code.
 */
-(NSInteger)orderCode
{
	return orderCode;
}

/* setResultStringWithFormat
 * Sets and formats a result string.
 */
-(void)setResultStringWithFormat:(NSString *)format, ...
{
	NSString * formattedString;
	va_list arguments;
	
	va_start(arguments, format);
#warning 64BIT: Check formatting arguments
	formattedString = [[NSString alloc] initWithFormat:format arguments:arguments];
	[self setResultString:formattedString];
	[formattedString release];
	va_end(arguments);
}

/* setResultString
 * Sets the result data for this task and also sets the last run date
 * for simplicity.
 */
-(void)setResultString:(NSString *)newResultString
{
	[newResultString retain];
	[resultString release];
	resultString = newResultString;
}

/* resultString
 * Return the result of the last run of this task.
 */
-(NSString *)resultString
{
	return resultString;
}

/* setLastRunDate
 * Sets the date when this task was last run.
 */
-(void)setLastRunDate:(NSDate *)newLastRunDate
{
	[newLastRunDate retain];
	[lastRunDate release];
	lastRunDate = newLastRunDate;
}

/* lastRunDate
 * Return the date when this task was last run.
 */
-(NSDate *)lastRunDate
{
	return lastRunDate;
}

/* setEarliestRunDate
 * Sets the earliest time when this task is allowed to run.
 */
-(void)setEarliestRunDate:(NSDate *)newEarliestRunDate
{
	[newEarliestRunDate retain];
	[earliestRunDate release];
	earliestRunDate = newEarliestRunDate;
}

/* earliestRunDate
 * Return the date that specifies the earliest time this task is
 * allowed to run.
 */
-(NSDate *)earliestRunDate
{
	return earliestRunDate;
}

/* compareForUniqueness
 * Compares the receiver task with the specified task and returns TRUE if
 * they're identical with respect to action code and data and folder name.
 */
-(BOOL)compareForUniqueness:(VTask *)task
{
	BOOL match = actionCode == [task actionCode];
	if (match)
		match = match && [folderName isEqualToString:[task folderName]];
	if (match)
		match = match && [actionData isEqualToString:[task actionData]];
	return match;
}

/* description
 * Return a formatted description of this task.
 */
-(NSString *)description
{
#warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"(code=%d, data='%@', order=%d, result=%d, resultData='%@')", actionCode, actionData, orderCode, resultCode, resultString];
}

/* taskCompare
 * Returns the result of comparing two items
 */
-(NSComparisonResult)taskCompare:(VTask *)otherObject
{
	if (orderCode < [otherObject orderCode]) return NSOrderedAscending;
	if (orderCode > [otherObject orderCode]) return NSOrderedDescending;
	return NSOrderedSame;
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[actionData release];
	[resultString release];
	[lastRunDate release];
	[earliestRunDate release];
	[super dealloc];
}
@end
