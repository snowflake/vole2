//
//  CheckForUpdates.h
//  Vienna
//
//  Created by Steve on Wed Mar 24 2004.
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

#import <Foundation/Foundation.h>
#import "Vole.h"

#import "AppController.h"
#import "MacPADSocket.h"

@interface CheckForUpdates : NSWindowController {
	IBOutlet NSButton * cancelButton;
	IBOutlet NSProgressIndicator * progressBar;
	IBOutlet NSWindow * updateWindow;
	BOOL updateAvailable;
	BOOL isShowingUI;
	NSString * updateStatus;
	NSString * updateTitle;
	NSString * updateURL;
	NSString * latestVersion;
	MacPADSocket * macPAD;
}

-(void)checkForUpdate:(NSWindow *)window showUI:(BOOL)showUI;
-(BOOL)isUpdateAvailable;
-(NSString *)updateTitle;
-(NSString *)updateStatus;
-(NSString *)updateURL;
-(NSString *)latestVersion;
-(void)setUpdateURL:(NSString *)newUpdateURL;
-(void)setLatestVersion:(NSString *)newLatestVersion;
@end

@interface AppController (CheckForUpdates)
	-(IBAction)checkForUpdates:(id)sender;
@end
