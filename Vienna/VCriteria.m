//
//  CriteriaTree.m
//  Vienna
//
//  Created by Steve on Thu Apr 29 2004.
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

#import "VCriteria.h"
#import "XMLParser.h"

@implementation VCriteria

/* init
 * Initialise an empty VCriteria.
 */
-(id)init
{
	return [self initWithField:@"" withOperator:0 withValue:@""];
}

/* initWithField
 * Initalises a new VCriteria with the specified values.
 */
-(id)initWithField:(NSString *)newField withOperator:(CriteriaOperator)newOperator withValue:(NSString *)newValue
{
	if ((self = [super init]) != nil)
	{
		[self setField:newField];
		[self setOperator:newOperator];
		[self setValue:newValue];
	}
	return self;
}

/* operatorString
 * Returns the string representation of the operator.
 * Note: do NOT localise these strings. For UI display, the caller should use
 * NSLocalizedString() on the return value.
 */
+(NSString *)stringFromOperator:(CriteriaOperator)op
{
	NSString * operatorString = nil;
	switch (op)
	{
		case MA_CritOper_Is:					operatorString = @"is"; break;
		case MA_CritOper_IsNot:					operatorString = @"is not"; break;
		case MA_CritOper_IsAfter:				operatorString = @"is after"; break;
		case MA_CritOper_IsBefore:				operatorString = @"is before"; break;
		case MA_CritOper_IsOnOrAfter:			operatorString = @"is on or after"; break;
		case MA_CritOper_IsOnOrBefore:			operatorString = @"is on or before"; break;
		case MA_CritOper_Contains:				operatorString = @"contains"; break;
		case MA_CritOper_NotContains:			operatorString = @"does not contain"; break;
		case MA_CritOper_IsLessThan:			operatorString = @"is less than"; break;
		case MA_CritOper_IsGreaterThan:			operatorString = @"is greater than"; break;
		case MA_CritOper_IsLessThanOrEqual:		operatorString = @"is less than or equal to"; break;
		case MA_CritOper_IsGreaterThanOrEqual:	operatorString = @"is greater than or equal to"; break;
	}
	return operatorString;
}

/* operatorFromString
 * Given a string representing an operator, returns the CriteriaOperator value
 * that represents that string.
 */
+(CriteriaOperator)operatorFromString:(NSString *)string
{
	NSArray * operatorArray = [VCriteria arrayOfOperators];
	NSUInteger index;
	
	for (index = 0; index < [operatorArray count]; ++index)
	{
		CriteriaOperator op = [[operatorArray objectAtIndex:index] intValue];
		if ([string isEqualToString:[VCriteria stringFromOperator:op]])
			return op;
	}
	return 0;
}

/* arrayOfOperators
 * Returns an array of NSNumbers that represent all supported operators.
 */
+(NSArray *)arrayOfOperators
{
	return [NSArray arrayWithObjects:
		[NSNumber numberWithLong:(long)MA_CritOper_Is],
		[NSNumber numberWithLong:(long)MA_CritOper_IsNot],
		[NSNumber numberWithLong:(long)MA_CritOper_IsAfter],
		[NSNumber numberWithLong:(long)MA_CritOper_IsBefore],
		[NSNumber numberWithLong:(long)MA_CritOper_IsOnOrAfter],
		[NSNumber numberWithLong:(long)MA_CritOper_IsOnOrBefore],
		[NSNumber numberWithLong:(long)MA_CritOper_Contains],
		[NSNumber numberWithLong:(long)MA_CritOper_NotContains],
		[NSNumber numberWithLong:(long)MA_CritOper_IsLessThan],
		[NSNumber numberWithLong:(long)MA_CritOper_IsLessThanOrEqual],
		[NSNumber numberWithLong:(long)MA_CritOper_IsGreaterThan],
		[NSNumber numberWithLong:(long)MA_CritOper_IsGreaterThanOrEqual],
		nil];
}

/* string
 * Returns a string representing the entire criteria.
 */
-(NSString *)string
{
// #warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"<criteria field='%@'><operator>%ld</operator><value>%@</value></criteria>", field, (long)operator, value];
}

/* setField
 * Sets the field element of a criteria.
 */
-(void)setField:(NSString *)newField
{
	field = newField;
}

/* setOperator
 * Sets the operator element of a criteria.
 */
-(void)setOperator:(CriteriaOperator)newOperator
{
	operator = newOperator;
}

/* setValue
 * Sets the value element of a criteria.
 */
-(void)setValue:(NSString *)newValue
{
	value = newValue;
}

/* field
 * Returns the field element of a criteria.
 */
-(NSString *)field
{
	return field;
}

/* operator
 * Returns the operator element of a criteria
 */
-(CriteriaOperator)operator
{
	return operator;
}

/* value
 * Returns the value element of a criteria.
 */
-(NSString *)value
{
	return value;
}

/* dealloc
 * Clean up and release resources.
 */
@end

@implementation VCriteriaTree

/* init
 * Initialise an empty CriteriaTree
 */
-(id)init
{
	return [self initWithString:@""];
}

/* criteriaTreeWithString
 * Initialises an autorelease criteria tree object with the specified string.
 */
-(id)initWithString:(NSString *)string
{
	if ((self = [super init]) != nil)
	{
		criteriaTree = [[NSMutableArray alloc] init];
		// deprecated API here DJE
		//		NSData * data = [NSData dataWithBytes:[string cString] length:[string length]];
		// replacement here
#ifdef VOLE2
        // **************************** Vole 2 *****************************
        const char * cString = [string UTF8String];
        NSData *data = [NSData dataWithBytes:cString length: strlen(cString)];
#else
        // **************************** Vole 1 *****************************
        // Search will not work if string contains Non-ASCII characters,
        // and it's a bit iffy even if it does. Switch to Vole 2 please.
        // Unicode makes sense even if CIX screw it up with Mojibake
        const char * cString = [string cStringUsingEncoding:
                                NSWindowsCP1252StringEncoding];
        NSData * data = [NSData dataWithBytes: cString
                                       length:strlen(cString)];
#endif
		XMLParser * xmlTree = [[XMLParser alloc] initWithData:data];
		XMLParser * criteriaGroup = [xmlTree treeByName:@"criteriagroup"];
		NSInteger index = 0;

		if (criteriaGroup != nil)
			while (index < [criteriaGroup countOfChildren])
			{
				XMLParser * subTree = [criteriaGroup treeByIndex:index];
				NSString * fieldName = [subTree valueOfAttribute:@"field"];
				NSString * operator = [[subTree treeByName:@"operator"] valueOfElement];
				NSString * value = [[subTree treeByName:@"value"] valueOfElement];
				
				VCriteria * newCriteria = [[VCriteria alloc] init];
				[newCriteria setField:fieldName];
				[newCriteria setOperator:[operator intValue]];
				[newCriteria setValue:value];
				[self addCriteria:newCriteria];
				++index;
			}
	}
	return self;
}

/* criteriaEnumerator
 * Returns an enumerator that will iterate over the criteria
 * object. We do it this way because we can't necessarily guarantee
 * that the criteria will be stored in an NSArray or any other collection
 * object for which NSEnumerator is supported.
 */
-(NSEnumerator *)criteriaEnumerator
{
	return [criteriaTree objectEnumerator];
}

/* addCriteria
 * Adds the specified criteria to the criteria array.
 */
-(void)addCriteria:(VCriteria *)newCriteria
{
	[criteriaTree addObject:newCriteria];
}

/* string
 * Returns the complete criteria tree as a string.
 */
-(NSString *)string
{
	NSString * criteriaString = @"<criteriagroup>";
	NSUInteger index;
	
	for (index = 0; index < [criteriaTree count]; ++index)
	{
		VCriteria * criteria = [criteriaTree objectAtIndex:index];
		criteriaString = [criteriaString stringByAppendingString:[criteria string]];
	}
	criteriaString = [criteriaString stringByAppendingString:@"</criteriagroup>"];
	return criteriaString;
}

/* dealloc
 * Clean up and release resources.
 */
@end
