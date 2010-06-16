//
//  FolderHeaderBar.h
//  Vienna
//
//  Created by Steve on Fri May 13 2005.
//  Copyright (c) 2005 Steve Palmer. All rights reserved.
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

@interface FolderHeaderBar : NSView {
	IBOutlet NSTextField * unreadCount;
	IBOutlet NSTextField * folderName;
	IBOutlet NSTextField * smallFolderName;
	IBOutlet NSTextField * folderDescription;
	Folder * currentFolder;
	int folderCount;
}

// Public functions
-(void)refreshForCurrentFolder;
-(void)setFolderCount:(int)newCount;
-(void)setCurrentFolder:(Database *)db folderId:(int)folderId;
@end
