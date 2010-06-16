//
//  ActivityViewer.m
//  Vienna
//
//  Created by Steve on Thu Mar 18 2004.
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

#import "ActivityViewer.h"

@implementation ActivityViewer

/* init
 * Just init the activity window.
 */
-(id)init
{
	return [super initWithWindowNibName:@"ActivityViewer"];
}

/* windowDidLoad
 * Set the font for the activity viewer
 */
-(void)windowDidLoad
{
	NSFont * font = [NSFont userFixedPitchFontOfSize:10];
	[textView setFont:font];
}

/* clearLog
 * Remove the last log
 */
-(void)clearLog
{
	[textView setString:@""];
}

/* writeString
 * Append the string to the end of the text in the activity window.
 */
-(void)writeString:(NSString *)string
{
	NSRange endRange;
	
	endRange.location = [[textView textStorage] length];
	endRange.length = 0;
	[textView replaceCharactersInRange:endRange withString:string];
	endRange.length = [string length];
	[textView scrollRangeToVisible:endRange];
}
@end
