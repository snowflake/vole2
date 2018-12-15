//
//  StringExtensions.m
//  Vienna
//
//  Created by Steve on Wed Mar 17 2004.
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

#import "StringExtensions.h"

@implementation NSMutableString (MutableStringExtensions)

/* replaceString
 * Replaces one string with another. This is just a simpler version of the standard
 * NSMutableString replaceOccurrencesOfString function with NSLiteralString implied
 * and the range set to the entire string.
 */
-(void)replaceString:(NSString *)source withString:(NSString *)dest
{
	[self replaceOccurrencesOfString:source withString:dest options:NSLiteralSearch range:NSMakeRange(0, [self length])];
}
@end

@implementation NSString (StringExtensions)

/* firstLine
 * Returns a string that contains just the first non-blank line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0.
 */
-(NSString *)firstLine
{
	return [self firstLineWithMaximumCharacters:[self length] allowEmpty:YES];
}

/* firstNonBlankLine
 * Returns the first line of the string that isn't entirely spaces or tabs.
 */
-(NSString *)firstNonBlankLine
{
	return [self firstLineWithMaximumCharacters:[self length] allowEmpty:NO];
}

/* firstLineWithMaximumCharacters
 * Returns a string that contains just the first non-blank line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0. A maximum of maxChars are
 * returned.
 */
-(NSString *)firstLineWithMaximumCharacters:(NSUInteger)maxChars allowEmpty:(BOOL)allowEmpty
{
	NSUInteger indexOfLastWord;
	NSUInteger indexOfChr;
	BOOL hasNonEmptyChars;
	unichar ch;
	NSRange r;
	
	r.location = 0;
	r.length = 0;
	indexOfChr = 0;
	indexOfLastWord = 0;
	hasNonEmptyChars = NO;
	if (maxChars > [self length])
		maxChars = [self length];
	while (indexOfChr < maxChars)
	{
		ch = [self characterAtIndex:indexOfChr];
		if (ch == '\r' || ch == '\n')
		{
			if ((r.length > 0 && allowEmpty) || (!allowEmpty && hasNonEmptyChars))
			{
				indexOfLastWord = r.length;
				break;
			}
			r.location += r.length + 1;
			r.length = -1;
			hasNonEmptyChars = NO;
		}
		else
		{
			if (ch == ' ' || ch == '\t')
				indexOfLastWord = r.length;
			else
				hasNonEmptyChars = YES;
		}
		++indexOfChr;
		++r.length;
	}
	if (r.length < maxChars)
		r.length = indexOfLastWord;
	if (r.location >= maxChars)
		r.location = maxChars - r.length;
	return [self substringWithRange:r];
}

/* secondAndSubsequentLines
 * Returns a string that contains just the first line of the
 * string of which this method is part. A line is assumed to
 * be terminated by any of \r, \n or \0.
 */
-(NSString *)secondAndSubsequentLines
{
	NSUInteger length = [self length];
	unichar ch = 0;
	NSRange r;

	r.location = 0;
	while (r.location < length)
	{
		ch = [self characterAtIndex:r.location];
		if (ch == '\r' || ch == '\n')
			break;
		++r.location;
	}
	if (ch == '\r')
	{
		if (++r.location < length)
			ch = [self characterAtIndex:r.location];
	}
	if (ch == '\n')
		++r.location;
	r.length = length - r.location;
	return [self substringWithRange:r];
}

/* indexOfCharacterInString
 * Returns the index of the first occurrence of the specified character after
 * the starting index.
 */
-(NSInteger)indexOfCharacterInString:(char)ch afterIndex:(NSInteger)startIndex
{
	NSInteger length = [self length];
	NSInteger index;

	if (startIndex < length - 1)
		for (index = startIndex; index < length; ++index)
		{
			if ([self characterAtIndex:index] == ch)
				return index;
		}
	return NSNotFound;
}

/* hasCharacter
 * Returns YES if the specified character appears in the string. NO otherwise.
 */
-(BOOL)hasCharacter:(char)ch
{
	return [self indexOfCharacterInString:ch afterIndex:0] != NSNotFound;
}

/* reversedString
 * Return the string reversed.
 */
-(NSString *)reversedString
{
// 2014-08-16 DJE: switch to ASCII encoding. This method is only
//                 used while scanning for Cix pronpts, not messages.
	const char * cString = [self cStringUsingEncoding:NSASCIIStringEncoding];
#if 0
	FILE *fp = fopen("/Users/davidevans/junk/reversed-strings.lst","a");
	fprintf(fp,"%s\n", cString);
	fclose(fp);
#endif
	char * rcString = strdup(cString);
	NSString * reversedString = nil;

	if (rcString != nil)
	{
		NSInteger length = strlen(cString);
		NSInteger p;
		
		for (p = 0; p < length; ++p)
			rcString[p] = cString[(length - p) - 1];
		rcString[p] = '\0';
		reversedString = [[NSMutableString alloc] initWithCString:rcString
														  encoding:NSASCIIStringEncoding];
		free(rcString);
	}
	return reversedString;
}

/* rewrapString
 * Reformat a string so that lines are broken at the specified
 * column.
 */
// This method is only used by Connect.m
-(NSMutableArray *)rewrapString:(NSInteger)wrapColumn
{
	NSMutableArray * arrayOfLines = [NSMutableArray array];
	// deprecated API was here, changed by DJE
	NSData  * newData = [ self dataUsingEncoding:NSWindowsCP1252StringEncoding allowLossyConversion: YES];
//	const char * cString = [self cStringUsingEncoding:NSWindowsCP1252StringEncoding];
	char *cString = (char *)malloc([newData length] + 1);
	char *tempBuff= cString;  /* free tempBuff later */
	[ newData getBytes: cString length: [newData length]];
	tempBuff[ [newData length]] = '\0';
	char * lineStart;
	NSInteger lineLength;
	NSInteger indexOfEndOfLastWord;
	BOOL inSpace;

	lineLength = 0;
	lineStart = cString;
	indexOfEndOfLastWord = 0;
	inSpace = NO;

	while (*cString)
	{
		if (*cString == ' ' || *cString == '\t')
		{
			if (!inSpace) {
				indexOfEndOfLastWord = lineLength;
				inSpace = YES;
			}
		}
		else
		{
			inSpace = NO;
		}
		if (*cString == '\n')
		{
			// Deprecated API here DJE
			//[arrayOfLines addObject:[NSString stringWithCString:lineStart length:lineLength]];
			// converted to
			[arrayOfLines addObject:[[NSString alloc] initWithBytes:lineStart 
															  length:lineLength
															encoding:NSWindowsCP1252StringEncoding]];
			// end of conversion

			lineLength = 0;
			indexOfEndOfLastWord = 0;
			lineStart = ++cString;
		}
		else if (lineLength == wrapColumn)
		{
			if (indexOfEndOfLastWord == 0)
				indexOfEndOfLastWord = lineLength;
			// deprecated API here DJE
//			[arrayOfLines addObject:[NSString stringWithCString:lineStart length:indexOfEndOfLastWord]];
			// replaced by
			[arrayOfLines addObject:[[NSString alloc ] initWithBytes: lineStart 
															   length:indexOfEndOfLastWord
															 encoding:NSWindowsCP1252StringEncoding]];
			// end of replacement

			lineLength = 0;
			lineStart += indexOfEndOfLastWord;
			
			while (*lineStart == ' ' || *lineStart == '\t')
				++lineStart;
			cString = lineStart;
		}
		else
		{
			++cString;
			++lineLength;
		}
	}
	if (lineLength)
		// deprecated API here DJE
		//[arrayOfLines addObject:[NSString stringWithCString:lineStart length:lineLength]];
		// replaced by
		[arrayOfLines addObject:[[NSString alloc ] initWithBytes:lineStart 
														   length:lineLength
														 encoding: NSWindowsCP1252StringEncoding ]];
	free(tempBuff);
	return arrayOfLines;
}
@end
