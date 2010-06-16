//
//  MissingMessagesController.h
//  Vienna
//
//  Created by Steve on Sun May 23 2004.
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

#import <AppKit/AppKit.h>
#import "Database.h"

@interface MissingMessagesController : NSWindowController {
	IBOutlet NSWindow * missingMessagesWindow;
	IBOutlet NSWindow * missingMessagesProgressWindow;
	IBOutlet NSButtonCell * fillExisting;
	IBOutlet NSButtonCell * fillBackToSpecific;
	IBOutlet NSButtonCell * skipBack;
	IBOutlet NSTextField * messageNumber;
	IBOutlet NSTextField * skipBackCount;
	IBOutlet NSTextField * progressInfo;
	IBOutlet NSProgressIndicator * progressBar;
	IBOutlet NSButton * stopButton;
	IBOutlet NSButton * okButton;
	NSWindow * parentWindow;
	Database * db;
	BOOL stopScanFlag;
	BOOL scanRunning;
	int countOfTasks;
	int countOfMessages;
	int countOfFolders;
	unsigned int skipBackValue;
	unsigned int requiredFirstMessage;
	NSArray * arrayOfFolders;
	NSArray * messagesArray;	
}

// Public functions
-(IBAction)doOK:(id)sender;
-(IBAction)doCancel:(id)sender;
-(IBAction)selectFillExisting:(id)sender;
-(IBAction)selectFillBackToSpecific:(id)sender;
-(IBAction)selectSkipBack:(id)sender;
-(IBAction)stopScan:(id)sender;
-(BOOL)isScanning;

-(void)getMissingMessages:(NSWindow *)window arrayOfFolders:(NSArray *)arrayOfFolders database:(Database *)database;
@end
