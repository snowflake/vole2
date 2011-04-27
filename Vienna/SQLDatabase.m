//
//  SQLDatabase.m
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import "SQLDatabase.h"
#import "SQLDatabasePrivate.h"

@implementation SQLDatabase

+ (id)databaseWithFile:(NSString*)inPath
{
	return [[[SQLDatabase alloc] initWithFile:inPath] autorelease];
}

#pragma mark -

-(id)initWithFile:(NSString*)inPath
{
	if( ![super init])
		return nil;
	
	mPath = [inPath copy];
	mDatabase = NULL;
	
	return self;
}

-(id)init
{
	if( ![super init])
		return nil;
	
	mPath = NULL;
	mDatabase = NULL;
	
	return self;
}

-(void)dealloc
{
	[self close];
	[mPath release];
	[super dealloc];
}

#pragma mark -

-(BOOL)open
{
	int	err;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	// If the new sqlite3 database does not exist then convert the old one (iff that exists!)
	if (![fm fileExistsAtPath: mPath])
	{
		NSLog(@"Database needs upgrading");
		[self upgradeFromSqlite2];
	}
	
	err = sqlite3_open( [mPath fileSystemRepresentation], &mDatabase );
	if( err != SQLITE_OK )
	{
		return NO;
	}
	
	return YES;
}

-(void)close
{
	if( !mDatabase )
		return;
	
	sqlite3_close( mDatabase );
	mDatabase = NULL;
}

#pragma mark -

+ (NSString*)prepareStringForQuery:(NSString*)inString
{
	NSMutableString*	string;
	NSRange				range = NSMakeRange( 0, [inString length]);
	NSRange				subRange;
	
	subRange = [inString rangeOfString:@"'" options:NSLiteralSearch range:range];
	if( subRange.location == NSNotFound )
		return inString;
	
	string = [NSMutableString stringWithString:inString];
	for( ; subRange.location != NSNotFound && range.length > 0;  )
	{
		subRange = [string rangeOfString:@"'" options:NSLiteralSearch range:range];
		if( subRange.location != NSNotFound )
			[string replaceCharactersInRange:subRange withString:@"''"];
		
		range.location = subRange.location + 2;
		range.length = ( [string length] < range.location ) ? 0 : ( [string length] - range.location );
	}
	
	return string;
}

-(int)lastInsertRowId
{
	if( !mDatabase )
		return -1;

	return sqlite3_last_insert_rowid( mDatabase );
}

-(SQLResult*)performQuery:(NSString*)inQuery
{
	SQLResult*	sqlResult = nil;
	char**		results;
	int			result;
	int			columns;
	int			rows;
	
	if( !mDatabase )
		return nil;
	// deprecated API here DJE
//	result = sqlite3_get_table( mDatabase, [inQuery lossyCString], &results, &rows, &columns, NULL );
	// replacement here
	NSData  *ls = [ inQuery dataUsingEncoding:NSWindowsCP1252StringEncoding allowLossyConversion: YES];
	char *qs = calloc( [ls length] +1, 1);
	if(qs == NULL){
		NSLog(@"calloc failed at %s %d",__FILE__, __LINE__);
		return nil;
	}
	[ ls getBytes: qs length: [ls length]];
	result = sqlite3_get_table( mDatabase, qs , &results, &rows, &columns, NULL );
	free(qs);
	// end of replacement
	if( result != SQLITE_OK )
	{
		sqlite3_free_table( results );
		return nil;
	}
	
	sqlResult = [[SQLResult alloc] initWithTable:results rows:rows columns:columns];
	if( !sqlResult )
		sqlite3_free_table( results );
	
	return sqlResult;
}

-(SQLResult*)performQueryWithFormat:(NSString*)inFormat, ...
{
	SQLResult*	sqlResult = nil;
	NSString*	query = nil;
	va_list		arguments;
	
	if( inFormat == nil )
		return nil;
	
	va_start( arguments, inFormat );
	
	query = [[NSString alloc] initWithFormat:inFormat arguments:arguments];
	sqlResult = [self performQuery:query];
	[query release];
	
	va_end( arguments );
	
	return sqlResult;
}

-(int)upgradeFromSqlite2
{
	int status;
	NSString *sqlite2 = [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"sqlite2"];
	NSString *cmd = [[NSString alloc] initWithFormat: @"echo '.dump'|%@ ~/Library/Vienna/database.db | /usr/bin/sqlite3 %@", sqlite2, mPath];

	NSTask *convertTask = [[NSTask alloc] init];
	[convertTask setLaunchPath: @"/bin/sh"];
	[convertTask setArguments: [NSArray arrayWithObjects:@"-c", cmd, nil]];

	[convertTask launch];
	[convertTask waitUntilExit];
	
	status = [convertTask terminationStatus];

	[convertTask release];
	[cmd release];
	return status;
}

@end
