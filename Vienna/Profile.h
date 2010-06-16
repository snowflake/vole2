//
//  Profile.h
//  Vienna
//
//  Created by Steve on 11/24/04.
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

@interface Profile : NSWindowController {
	IBOutlet NSImageView * personImage;
	IBOutlet NSTextField * personName;
	IBOutlet NSTextField * personFullName;
	IBOutlet NSTextField * personEmailAddress;
	IBOutlet NSTextView * personResume;
	IBOutlet NSButton * updateButton;
	IBOutlet NSButton * sendMailButton;
	IBOutlet NSTextField * noImageText;
	IBOutlet NSTextField * noResumeText;
	VPerson * currentPerson;
	Database * db;
}

// Public functions
-(id)initWithDatabase:(Database *)theDb;
-(void)setCurrentPerson:(VPerson *)newPerson;
-(VPerson *)currentPerson;

// Action functions
-(IBAction)updateResume:(id)sender;
-(IBAction)sendMail:(id)sender;
-(IBAction)pictureUpdated:(id)sender;
@end
