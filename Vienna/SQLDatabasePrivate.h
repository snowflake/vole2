//
//  SQLDatabasePrivate.h
//  SQLite Test
//
//  Created by Dustin Mierau on Tue Apr 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Vole.h"
#import "SQLDatabase.h"

@interface SQLDatabase (Private)
@end

@interface SQLResult (Private)
-(id)initWithTable:(char**)inTable rows:(NSInteger)inRows columns:(NSInteger)inColumns;
@end

@interface SQLRowEnumerator : NSEnumerator
{
	SQLResult*	mResult;
	NSInteger			mPosition;
	IMP			mRowAtIndexMethod;
	NSInteger			(*mRowCountMethod)(SQLResult*, SEL);
}

-(id)initWithResult:(SQLResult*)inResult;

@end

@interface SQLRow (Private)
-(id)initWithColumns:(char**)inColumns rowData:(char**)inRowData columns:(NSInteger)inColumnCount;
-(BOOL)valid;
@end
