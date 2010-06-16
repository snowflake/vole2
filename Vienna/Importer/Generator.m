#import "Generator.h"
#include <sys/stat.h>

@implementation ParentFolder
-(NSString *)name
{
	return folderName;
}

-(BOOL)isCix
{
	return isCix;
}
-(int)parent
{
	return parentId;
}

-(id)initFolder:(NSString *)name parent:(int)parent isCix:(int)cix
{
	if ((self = [super init]))
	{
		folderName = name;
		parentId = parent;
		isCix = cix;
	}
	return self;
}
@end


@implementation Generator

static int nowProcessing = 0;

-(IBAction)quit:(id)sender
{
	if (nowProcessing)
	{
		nowProcessing = 0;
	}
	else
	{
		[progressBar stopAnimation: self];
		[textField setStringValue: @"Stopped"];
		exit(0);
	}
}

-(IBAction)start:(id)sender
{
	[startButton setState: NSOffState];
	[progressBar startAnimation: self];
	nowProcessing = 1;
	
	[NSThread detachNewThreadSelector: @selector(workThread:) toTarget: self withObject: nil];
}

-(void)workThread:(id)ignored
{
	NSAutoreleasePool *pool;
	pool = [[NSAutoreleasePool alloc] init];

	[textField setStringValue: @"Opening database"];	
	
	if (![self openDatabase])
	{
		[textField setStringValue: @"Can't open database"];
	}
	else
	{
		[textField setStringValue: @"Getting folder names"];
		[self readFolderNames];
		[textField setStringValue: @"Getting messages"];	
		[self doMessages];
	}

	[progressBar stopAnimation: self];
	[textField setStringValue: @"Finished"];
	
	nowProcessing = 0;	
	[pool release];
}

-(BOOL)openDatabase
{
	NSString *shortDbName = @"~/Library/Vienna/database3.db";
	NSString *dbFilename = [shortDbName stringByExpandingTildeInPath];

	sqlDatabase = [[SQLDatabase alloc] initWithFile: dbFilename];
	if (!sqlDatabase || ![sqlDatabase open])
		return NO;

	return YES;
}
	
-(void)doMessages
{
	SQLResult *results;
	int lastFolder = -1;
	NSString *shortCachePath = @"~/Library/Caches/Metadata/Vienna/";
	NSString *cachePath = [shortCachePath stringByExpandingTildeInPath];
	NSString *folderCachePath;
//	int count = 0;// TEMP, just do a few
	
	// TODO: This may fail if the parent directories are not there.
	[[NSFileManager defaultManager] createDirectoryAtPath: cachePath attributes: nil];
	
	results = [sqlDatabase performQuery:@"select * from messages order by folder_id"];
	if (results && [results rowCount])
	{
		NSEnumerator * enumerator = [results rowEnumerator];
		SQLRow * row;
		
		while ((row = [enumerator nextObject]) && nowProcessing)
		{
			int messageId = [[row stringForColumn:@"message_id"] intValue];
			int folderId = [[row stringForColumn:@"folder_id"] intValue];
			NSString *senderName = [row stringForColumn:@"sender"];
			NSString *text = [row stringForColumn:@"text"];
			NSDate *messageDate = [NSDate dateWithTimeIntervalSince1970:[[row stringForColumn:@"date"] doubleValue]];			
			
			// Ignore non-CIX messages
			ParentFolder *folder = [folderArray objectForKey: [NSNumber numberWithInt: folderId]];
			if (![folder isCix])
				continue;

			NSString *folderName = [folder name];
			NSString *cixURL = [NSString stringWithFormat: @"cix:%@:%d", folderName, messageId];
			NSString *displayName = [NSString stringWithFormat: @"%@ %@", cixURL, senderName];

			// Display where we've got to.
			if (lastFolder != folderId)
			{
				[textField setStringValue: folderName];
				lastFolder = folderId;
				
				// Create the subfolder
				folderCachePath = [NSString stringWithFormat: @"%@/%04d", cachePath, folderId];
				[[NSFileManager defaultManager] createDirectoryAtPath: folderCachePath attributes: nil];
			}
			
			NSDictionary *attribsDict;
			attribsDict = [NSDictionary dictionaryWithObjectsAndKeys:	
					    displayName, kMDItemDisplayName, 
						@"Vienna URL", kMDItemKind,
						cixURL, kMDItemPath,
						cixURL, @"kMDItemURL",
						cixURL, @"URL", // This is the one Finder uses.
						text, kMDItemTextContent,
						//title, kMDItemTextContent,
						messageDate, kMDItemContentModificationDate,
						messageDate, kMDItemContentCreationDate,
						messageDate, kMDItemLastUsedDate,
						[NSArray arrayWithObjects: senderName, nil], kMDItemAuthors,
						nil, nil];
			
			NSString *mdFilename = [NSString stringWithFormat: @"%@/%06d.cixurl", folderCachePath, messageId];

			// Don't overwrite existing files.
			struct stat st;
			if (stat([mdFilename UTF8String], &st) == 0)
				continue;

			[attribsDict writeToFile: mdFilename atomically: YES];
			
			// Make it a finder-openable URL file, and fake the creation date.
			NSNumber *creatorCode = [NSNumber numberWithUnsignedLong:'MACS'];
			NSNumber *typeCode = [NSNumber numberWithUnsignedLong:'ilht'];
			NSDictionary *fileAttr = [NSDictionary dictionaryWithObjectsAndKeys:
										creatorCode, NSFileHFSCreatorCode,
										typeCode, NSFileHFSTypeCode,
										messageDate, NSFileCreationDate,
										messageDate, NSFileModificationDate,
									    nil, nil];
			[[NSFileManager defaultManager] changeFileAttributes: fileAttr atPath: mdFilename];
//			if (++count > 10) break;
		}
	}
	[results release];
}

-(void)readFolderNames
{
	SQLResult *results;
	
	folderArray = [[NSMutableDictionary alloc] init];
	
	// Make sure we get the parents first.
	results = [sqlDatabase performQuery:@"select * from folders order by parent_id,folder_id"];
	if (results && [results rowCount])
	{
		NSEnumerator * enumerator = [results rowEnumerator];
		SQLRow * row;
		
		while ((row = [enumerator nextObject]))
		{
			int folderId = [[row stringForColumn:@"folder_id"] intValue];
			int parentId = [[row stringForColumn:@"parent_id"] intValue];
			NSString * name = [row stringForColumn:@"foldername"];
		
			// Make the full name and store that.
			NSString *fullName;
			ParentFolder *parentFolder = [folderArray objectForKey: [NSNumber numberWithInt: parentId]];
			NSString *parentName = [parentFolder name];
			Boolean isCix;
			int grandParentId = [parentFolder parent];
			if (grandParentId == 4)
			{
				fullName = [NSString stringWithFormat: @"%@/%@", parentName, name];
				isCix = YES;
			}
			else 
			{
				fullName = name;
				isCix = NO;
			}
			
			NSLog(@"got folder %d/%d %@ (%d)\n", folderId, parentId, fullName, isCix);
			ParentFolder *thisFolder = [[ParentFolder alloc] initFolder: fullName parent: parentId isCix: isCix];
			[folderArray setObject: thisFolder forKey: [NSNumber numberWithInt: folderId]];
		}
		[results release];
	}
}

@end
