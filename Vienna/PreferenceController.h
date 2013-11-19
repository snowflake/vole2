//
//  PreferenceController.h
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
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
#import <ApplicationServices/ApplicationServices.h>
#import "Credentials.h"
#import "VPerson.h"

@interface PreferenceController : NSWindowController {
	IBOutlet NSTextField * username;
	IBOutlet NSSecureTextField * password;
	IBOutlet NSColorWell * quoteColour;
	IBOutlet NSColorWell * priorityColour;
	IBOutlet NSColorWell * ignoredColour;
	IBOutlet NSPopUpButton * messageListFont;
	IBOutlet NSComboBox * messageListFontSize;
	IBOutlet NSPopUpButton * messageFont;
	IBOutlet NSComboBox * messageFontSize;
	IBOutlet NSPopUpButton * plainTextFont;
	IBOutlet NSComboBox * plainTextFontSize;
	IBOutlet NSPopUpButton * folderFont;
	IBOutlet NSComboBox * folderFontSize;
	IBOutlet NSPopUpButton * checkFrequency;
	IBOutlet NSTableView * signaturesList;
	IBOutlet NSButton * newSignatureButton;
	IBOutlet NSButton * editSignatureButton;
	IBOutlet NSButton * deleteSignatureButton;
	IBOutlet NSButton * saveSignatureButton;
	IBOutlet NSButton * cancelSignatureButton;
	IBOutlet NSTextView * signatureText;
	IBOutlet NSTextField * signatureTitle;
	IBOutlet NSWindow * signatureEditor;
	IBOutlet NSPopUpButton * defaultSignature;
	IBOutlet NSTextField * recentCount;
	IBOutlet NSPopUpButton * linksHandler;
	IBOutlet NSPopUpButton * connectionType;
	IBOutlet NSButton * onlineWhenStarting;
	IBOutlet NSButton * checkForUpdates;
	IBOutlet NSButton * enableMugshots;
	IBOutlet NSTextField * mugshotFolder;
	IBOutlet NSButton * mugshotFolderBrowse;
	IBOutlet NSButton * mugshotFolderDefault;
	IBOutlet NSTextField * profileFullName;
	IBOutlet NSTextField * profileEmailAddress;
	IBOutlet NSTextField * profileResume;
	IBOutlet NSWindow * resumeEditor;
	IBOutlet NSButton * saveResumeButton;
	IBOutlet NSButton * cancelResumeButton;
	IBOutlet NSTextView * resumeText;
	IBOutlet NSButton * saveSpotlightMetadata;
	IBOutlet NSButton * autoCollapseFolders;
	IBOutlet NSTextField * logVersions;
	IBOutlet NSTextField * downloadFolder;
	IBOutlet NSButton * downloadMugshots;
	ICInstance internetConfigHandler;
	Credentials * credentials;
	NSString * savedUsername;
	NSString * savedPassword;
	NSArray * arrayOfSignatures;
	NSString * signatureBeingEdited;
	NSString * mugshotsFolderName;
	NSNumber * mugshotsEnabled;
	VPerson * currentPerson;
}

// Action functions
-(IBAction)changeUsername:(id)sender;
-(IBAction)changePassword:(id)sender;
-(IBAction)changeQuoteColour:(id)sender;
-(IBAction)changePriorityColour:(id)sender;
-(IBAction)changeIgnoredColour:(id)sender;
-(IBAction)changeFont:(id)sender;
-(IBAction)changeRecentCount:(id)sender;
-(IBAction)changeCheckFrequency:(id)sender;
-(IBAction)newSignature:(id)sender;
-(IBAction)editSignature:(id)sender;
-(IBAction)deleteSignature:(id)sender;
-(IBAction)saveSignature:(id)sender;
-(IBAction)cancelSignature:(id)sender;
-(IBAction)selectDefaultSignature:(id)sender;
-(IBAction)selectDefaultLinksHandler:(id)sender;
-(IBAction)selectConnectionType:(id)sender;
-(IBAction)changeOnlineWhenStarting:(id)sender;
-(IBAction)changeCheckForUpdates:(id)sender;
-(IBAction)changeMugshots:(id)sender;
-(IBAction)changeMugshotFolder:(id)sender;
-(IBAction)browseMugshotFolder:(id)sender;
-(IBAction)defaultMugshotFolder:(id)sender;
-(IBAction)changeProfileFullName:(id)sender;
-(IBAction)changeProfileEmailAddress:(id)sender;
-(IBAction)editResume:(id)sender;
-(IBAction)saveResume:(id)sender;
-(IBAction)cancelResume:(id)sender;
-(IBAction)changeSpotlight:(id)sender;
-(IBAction)changeAutoCollapseFolders:(id)sender;
-(IBAction)changeLogVersions:(id)sender;
-(IBAction)changeMugshotsDownload:(id)sender;
-(IBAction)changeDownloadFolder:(id)sender;
-(IBAction)browseDownloadFolder:(id)sender;

// General functions
-(void)initializePreferences;
-initWithCredentials:(Credentials *)credentials;
@end
