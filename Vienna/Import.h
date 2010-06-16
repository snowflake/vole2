//
//  Import.h
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
#import "BufferedFile.h"
#import "AppController.h"

@interface AppController (Import)
	-(void)importOpenPanel:(SEL)importHandler;
	-(IBAction)importCIXScratchpad:(id)sender;
	-(IBAction)importRSSSubscriptions:(id)sender;
@end

@interface ImportController : NSWindowController {
	Database * db;
	NSString * importFilename;
	IBOutlet NSWindow * importSheet;
	IBOutlet NSTextField * progressInfo;
	IBOutlet NSProgressIndicator * progressBar;
	IBOutlet NSButton * stopButton;
	BOOL stopImportFlag;
	BOOL importRunning;
	int lastTopicId;
}

// Action handlers
-(IBAction)stopImport:(id)sender;

// Public functions
-(BOOL)isImporting;
-(void)import:(NSWindow *)window pathToFile:(NSString *)pathToFile database:(Database *)db;
@end
