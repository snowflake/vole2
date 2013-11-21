//
//  SQLRow.m
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import "SQLDatabase.h"
#import "SQLDatabasePrivate.h"
#import "sanitise_string.h"
@implementation SQLRow

// #warning: more work is required in this file 
-(id)initWithColumns:(char**)inColumns rowData:(char**)inRowData columns:(NSInteger)inColumnCount
{
	if( ![super init])
		return nil;
	
	mRowData = inRowData;
	mColumns = inColumns;
	mColumnCount = inColumnCount;
	
	return self;
}

-(id)init
{
	if( ![super init])
		return nil;
	
	mRowData = NULL;
	mColumns = NULL;
	mColumnCount = 0;
	
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

#pragma mark -

-(NSInteger)columnCount
{
	return mColumnCount;
}

#pragma mark -

-(NSString*)nameOfColumnAtIndex:(NSInteger)inIndex
{
	if( inIndex >= mColumnCount || ![self valid])
		return nil;
	// deprecated API was here DJE
	//	return [NSString stringWithCString:mColumns[ inIndex ]];
	//replacement here
	return [NSString stringWithCString:mColumns[ inIndex ] encoding:NSWindowsCP1252StringEncoding];

}

-(NSString*)nameOfColumnAtIndexNoCopy:(NSInteger)inIndex
{
	if( inIndex >= mColumnCount || ![self valid])
		return nil;
// deprecated API here DJE
// #warning are there more initWithCStringNoCopy in the rest of the source?
//	return [[[NSString alloc] initWithCStringNoCopy:mColumns[ inIndex ] length:strlen( mColumns[ inIndex ]) freeWhenDone:NO] autorelease];
// replace with:
	return /* DJE [ */ [[NSString alloc] initWithBytesNoCopy: sanitise_string( mColumns[ inIndex ] )
												 length: strlen( mColumns[ inIndex ] )
											   encoding: NSWindowsCP1252StringEncoding
										   freeWhenDone: NO]/* autorelease DJE do we need this? ]  */;
	}

#pragma mark -

-(NSString*)stringForColumn:(NSString*)inColumnName
{
	NSInteger index;
	
	if( ![self valid])
		return nil;
	
	for( index = 0; index < mColumnCount; index++ )
		//deprecated API here DJE
		//if( strcmp( mColumns[ index ], [inColumnName cString]) == 0 )
		// replacement here
		if( strcmp( mColumns[ index ],
				   [inColumnName cStringUsingEncoding:NSWindowsCP1252StringEncoding]) == 0 )
			break;
	
	return [self stringForColumnAtIndex:index];
}

-(NSString*)stringForColumnNoCopy:(NSString*)inColumnName
{
	NSInteger index;
	
	if( ![self valid])
		return nil;
	
	for( index = 0; index < mColumnCount; index++ )
		// deprecated API here DJE
		//if( strcmp( mColumns[ index ], [inColumnName cString]) == 0 )
		// replcement here
		if( strcmp( mColumns[ index ], [inColumnName cStringUsingEncoding:NSWindowsCP1252StringEncoding]) == 0 )
			break;
	
	return [self stringForColumnAtIndexNoCopy:index];
}

-(NSString*)stringForColumnAtIndex:(NSInteger)inIndex
{
	if( inIndex >= mColumnCount || ![self valid])
		return nil;

	if (mRowData[ inIndex ] == nil) // PJC
		return @"";
	// deprecated API here DJE
	// return [NSString stringWithCString:mRowData[ inIndex ]];
	// replacement here
	return [NSString stringWithCString: sanitise_string(mRowData[ inIndex ])
							  encoding:NSWindowsCP1252StringEncoding];

	
}

-(NSString*)stringForColumnAtIndexNoCopy:(NSInteger)inIndex
{
	if( inIndex >= mColumnCount || ![self valid])
		return nil;
	//  deprecated API here
	// 	return [[[NSString alloc] initWithCStringNoCopy:mRowData[ inIndex ] length:strlen( mRowData[ inIndex ]) freeWhenDone:NO] autorelease];
	// replacement here
	return /* DJE [ */ [[NSString alloc] initWithBytesNoCopy: sanitise_string(mRowData[ inIndex ])
										   length: strlen( mRowData[ inIndex ])
										 encoding: NSWindowsCP1252StringEncoding
									 freeWhenDone: NO] /*autorelease  DJE ] */;

}

#pragma mark -

-(NSString*)description
{
	NSMutableString*	string = [NSMutableString string];
	NSInteger					column;
	
	for( column = 0; column < mColumnCount; column++ )
	{
		if( column ) [string appendString:@" | "];
		[string appendFormat:@"%s", mRowData[ column ]];
	}
	
	return string;
}

#pragma mark -

-(BOOL)valid
{
	return ( mRowData != NULL && mColumns != NULL && mColumnCount > 0 );
}

@end
