/* Generator */

#import <Cocoa/Cocoa.h>
#import "SQLDatabase.h"

@interface Generator : NSObject
{
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSTextField *textField;
	IBOutlet NSButton *startButton;
	SQLDatabase * sqlDatabase;
	NSMutableDictionary *folderArray;
}

- (IBAction)quit:(id)sender;
- (IBAction)start:(id)sender;

-(BOOL)openDatabase;
-(void)doMessages;
-(void)readFolderNames;
-(void)workThread:(id)ignored;

@end


@interface ParentFolder : NSObject
{
	NSString *folderName;
	int parentId;
	BOOL isCix;
};
-(NSString *)name;
-(BOOL)isCix;
-(int)parent;
-(id)initFolder:(NSString *)name parent:(int)parent isCix:(int)cix;
@end
