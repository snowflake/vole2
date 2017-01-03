//
//  SQLResult.m
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import "SQLDatabase.h"
#import "SQLDatabasePrivate.h"

@implementation SQLResult

static SEL sRowAtIndexSelector;
static SEL sRowCountSelector;

+ (void)initialize
{
	if( self != [SQLResult class])
		return;
	
	sRowAtIndexSelector = @selector( rowAtIndex: );
	sRowCountSelector = @selector( rowCount );
}

#pragma mark -

-(id)initWithTable:(char**)inTable rows:(NSInteger)inRows columns:(NSInteger)inColumns
{
	if( !(self=[super init]))
		return nil;
	
	mTable = inTable;
	mRows = inRows;
	mColumns = inColumns;
	
	return self;
}

-(id)init
{
	if( !(self=[super init]) )
		return nil;
	
	mTable = NULL;
	mRows = 0;
	mColumns = 0;
	
	return self;
}

-(void)dealloc
{
	if( mTable )
	{
		sqlite3_free_table( mTable );
		mTable = NULL;
	}
	
	[super dealloc];
}

#pragma mark -

-(NSInteger)rowCount
{
	return mRows;
}

-(NSInteger)columnCount
{
	return mColumns;
}

#pragma mark -

-(SQLRow*)rowAtIndex:(NSInteger)inIndex
{
	if( inIndex >= mRows )
		return nil;
	
	return [[[SQLRow alloc] initWithColumns:mTable rowData:( mTable + ( ( inIndex + 1 ) * mColumns ) ) columns:mColumns] autorelease];
}

-(NSEnumerator*)rowEnumerator
{
	return [[[SQLRowEnumerator allocWithZone:[self zone]] initWithResult:self] autorelease];
}

@end

#pragma mark -

@implementation SQLRowEnumerator

-(id)initWithResult:(SQLResult*)inResult
{
	if( !(self=[super init]))
		return nil;
	
	mResult = [inResult retain];
	mPosition = 0;
	mRowAtIndexMethod = [mResult methodForSelector:sRowAtIndexSelector];
	mRowCountMethod = (NSInteger (*)(SQLResult*, SEL))[mResult methodForSelector:sRowCountSelector];
	
	return self;
}

-(void)dealloc
{
	[mResult release];
	[super dealloc];
}

-(id)nextObject
{
	if( mPosition >= (*mRowCountMethod)(mResult, sRowCountSelector) )
		return nil;
	/*
         * ENABLE_STRICT_OBJC_MSGSEND = YES in a xcconfig file, or elsewhere,
         * will cause the next line to give an error:
         * "too many arguments to function call, expected 0, have 3"
         */
	return (*mRowAtIndexMethod)(mResult, sRowAtIndexSelector, mPosition++);
}

@end
