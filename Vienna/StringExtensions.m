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
#import "cp1252utf8.h"

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
		reversedString = [[[NSMutableString alloc] initWithCString:rcString
														  encoding:NSASCIIStringEncoding] autorelease];
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
			[arrayOfLines addObject:[[[NSString alloc] initWithBytes:lineStart 
															  length:lineLength
															encoding:NSWindowsCP1252StringEncoding] autorelease]];
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
			[arrayOfLines addObject:[[[NSString alloc ] initWithBytes: lineStart 
															   length:indexOfEndOfLastWord
															 encoding:NSWindowsCP1252StringEncoding] autorelease]];
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
		[arrayOfLines addObject:[[[NSString alloc ] initWithBytes:lineStart 
														   length:lineLength
														 encoding: NSWindowsCP1252StringEncoding ] autorelease]];
	free(tempBuff);
	return arrayOfLines;
}



/*
 * convert a string to utf - 8. The string can contain CP1252 or UTF - 8
 * sequences.CP1252 will be converted to UTF-8
 */

-(NSString *) vlconvertToUTF8 {
    
    const char * cp1252string = [self cStringUsingEncoding: NSWindowsCP1252StringEncoding];
    const char * convertedstring = utf8process( (unsigned char *)cp1252string);
    NSString * returnString = [[NSString alloc] initWithUTF8String: convertedstring];
    free((void *)convertedstring);
    [returnString autorelease];
    return returnString;
    
}


#define UNICODE_MAX	0x10FFFF
#define MIN_SURROGATE 	0xD800
#define MAX_SURROGATE   0xDFFF
static int		unicode_min[] = {0, 0, 0x80, 0x800, 0x10000};	/* min values for each
                                                                 * sequence */
static int		initial_mask[] = {0, 0x7f, 0x1f, 0x0f, 0x7};	/* mask values for the
                                                                 * initial byte */

#define valid_tail(in) ((input[in] & 0xc0 ) == 0x80)
#define copy() 		*output++ = input[i++]

static int
check_utf8(int length, unsigned char *buff)
{
    /*
     * Check the UTF-8 sequence at buff, length is the sequence length.
     * Returns 0 if OK, 1 if >MAX, 2 if overlong, 3 if surrogate
     */
    int		    rc = -1;
    int		    i;
    int		    codepoint = 0;
    codepoint = (*buff++ & initial_mask[length]);
    for (i = length; i > 1; i--) {
        codepoint = (codepoint << 6) | (*buff++ & 0x3f);
    }
    if (codepoint > UNICODE_MAX || codepoint < 0)
        rc = 1;
    else if (codepoint < unicode_min[length])
        rc = 2;			/* overlong seq */
    else if (codepoint >= MIN_SURROGATE && codepoint <= MAX_SURROGATE)
        rc = 3;			/* surrogate */
    else
        rc = 0;
#if 0
    fprintf(stderr, "codepoint = %x, rc = %d \n", codepoint, rc);
#endif
    return rc;
}



/*
 * returns a malloc'ed buffer, which must be free'd after use
 */
static char           *
utf8process(unsigned char *input)
{
    
    if (input == NULL)
        return (NULL);
    
    size_t	    end = strlen((char *)input);
    unsigned char           *base = malloc((end * 4) + 1);
    if (base == NULL)
        return (NULL);
    unsigned char           *output = base;
    
    size_t	    i;
    for (i = 0; i < end;) {
        if ((input[i] & 0x80) == 0) {
            /* It 's ASCII */
            copy();
            continue;
        }
        /* Look for multibyte sequences */
        if (((input[i] & 0xE0) == 0xC0) && valid_tail(i + 1)) {
            /* 2 byte sequence */
            if (check_utf8(2, input + i))
                goto cp1252;
            copy();
            copy();
            continue;
        }
        if (((input[i] & 0xF0) == 0xE0) && valid_tail(i + 1) && valid_tail(i + 2)) {
            /* 3 byte sequence */
            if (check_utf8(3, input + i))
                goto cp1252;
            copy();
            copy();
            copy();
            continue;
        }
        if (((input[i] & 0xF8) == 0xF0)
            && valid_tail(i + 1) && valid_tail(i + 2) &&
            valid_tail(i + 3)) {
            /* 4 byte sequence */
            if (check_utf8(4, input + i))
                goto cp1252;
            copy();
            copy();
            copy();
            copy();
            continue;
        }
    cp1252:
        /* Assume it is genuine cp1252 */
        strcpy( (char *)output, codetable[input[i]].utf8bytes);
        output += codetable[input[i]].nbytes;
        i++;
        continue;
        
    }
    *output = '\0';
    /* terminate the string; */
    return (char *)base;
}



@end
