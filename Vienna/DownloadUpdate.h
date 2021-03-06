//
//  DownloadUpdate.h
//  Vienna
//
//  Created by Steve on Wed Apr 09 2004.
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

@interface DownloadUpdate : NSWindowController {
	IBOutlet NSButton * cancelButton;
	IBOutlet NSProgressIndicator * progressBar;
	IBOutlet NSTextField * titleString;
	IBOutlet NSTextField * progressString;
	IBOutlet NSWindow * updateWindow;
	NSURLDownload * theDownload;
// #warning 64BIT: Inspect use of long
	long expectedLength;
// #warning 64BIT: Inspect use of long
	long bytesReceived;
}

-(IBAction)cancelButton:(id)sender;
-(void)download:(NSWindow *)window fromURL:(NSString *)fromURL toFilename:(NSString *)toFilename;
@end
