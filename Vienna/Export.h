//
//  Export.h
//  Vienna
//
//  Created by Steve on 5/27/05.
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

#import <Cocoa/Cocoa.h>
#import "Database.h"
#import "AppController.h"

@interface AppController (Export)
	-(void)exportSavePanel:(SEL)importHandler;
	-(IBAction)exportCIXScratchpad:(id)sender;
	-(IBAction)exportRSSSubscriptions:(id)sender;
@end

@interface ExportController : NSWindowController {
	Database * db;
	NSString * exportFilename;
	IBOutlet NSWindow * exportSheet;
	IBOutlet NSTextField * progressInfo;
	IBOutlet NSProgressIndicator * progressBar;
	IBOutlet NSButton * stopButton;
	NSArray * messages;
	NSString * messageText;
	BOOL exportRunning;
	BOOL stopExportFlag;
	int countOfFolders;
	int lastFolderId;
}

// Action handlers
-(IBAction)stopExport:(id)sender;

// Public functions
-(void)export:(NSWindow *)window pathToFile:(NSString *)pathToFile database:(Database *)database arrayOfFolders:(NSArray *)arrayOfFolders;
-(BOOL)isExporting;
@end
