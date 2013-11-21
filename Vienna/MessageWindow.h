//
//  MessageWindow.h
//  Vienna
//
//  Created by Steve on Sun Mar 14 2004.
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
#import "Vole.h"
#import "Database.h"

@interface MessageWindow : NSWindowController {
	IBOutlet NSWindow * messageWindow;
	IBOutlet NSTextView * textView;
	IBOutlet NSTextField * subjectLine;
	IBOutlet NSTextField * postToLine;
	IBOutlet NSPopUpButton * signaturesList;
	NSString * currentSignature;
	VMessage * message;
	Database * db;
}

// Init functions
-(id)initNewMessage:(Database *)db recipient:(NSString *)recipient commentNumber:(int)commentNumber initialText:(NSString *)initialText;
-(id)initMessageFromMessage:(Database *)theDb message:(VMessage *)message;

// Accessors
-(VMessage *)message;

// Action messages
-(IBAction)saveAsDraft:(id)sender;
-(IBAction)sendMessage:(id)sender;
-(IBAction)signatureSelected:(id)sender;

-(BOOL)windowShouldClose:(NSNotification *)notification;
@end
