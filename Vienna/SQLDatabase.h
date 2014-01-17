//
//  SQLDatabase.h
//  An objective-c wrapper for the SQLite library
//  available at http://www.hwaci.com/sw/sqlite/
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2002 Blackhole Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Vole.h"
#import "sqlite3.h"

@class SQLResult;
@class SQLRow;

@interface SQLDatabase : NSObject 
{
	sqlite3*	mDatabase;
	NSString*	mPath;
}

+ (id)databaseWithFile:(NSString*)inPath;
-(id)initWithFile:(NSString*)inPath;

-(BOOL)open;
-(void)close;

+ (NSString*)prepareStringForQuery:(NSString*)inString;
-(SQLResult*)performQuery:(NSString*)inQuery;
-(SQLResult*)performQueryWithFormat:(NSString*)inFormat, ...;

-(NSInteger)lastInsertRowId;
-(NSInteger)upgradeFromSqlite2;

@end

@interface SQLResult : NSObject
{
	char**	mTable;
	NSInteger		mRows;
	NSInteger		mColumns;
}

-(NSInteger)rowCount;
-(NSInteger)columnCount;

-(SQLRow*)rowAtIndex:(NSInteger)inIndex;
-(NSEnumerator*)rowEnumerator;

@end

@interface SQLRow : NSObject
{
	char**	mRowData;
	char**	mColumns;
	NSInteger		mColumnCount;
}

-(NSInteger)columnCount;

-(NSString*)nameOfColumnAtIndex:(NSInteger)inIndex;
-(NSString*)nameOfColumnAtIndexNoCopy:(NSInteger)inIndex;

-(NSString*)stringForColumn:(NSString*)inColumnName;
-(NSString*)stringForColumnNoCopy:(NSString*)inColumnName;
-(NSString*)stringForColumnAtIndex:(NSInteger)inIndex;
-(NSString*)stringForColumnAtIndexNoCopy:(NSInteger)inIndex;

@end
