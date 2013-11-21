//
//  Forum.h
//  Vienna
//
//  Created by Steve on Thu Jun 17 2004.
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

#define MA_Closed_Conference		0
#define MA_Open_Conference			1
#define MA_All_Conferences			2
#define MA_Empty_Conference			3

@interface Forum : NSObject {
	int nodeId;
	int categoryId;
	int status;
	int folderId;
	NSDate * lastActiveDate;
	NSString * name;
	NSString * description;
}

// Public functions
-(id)initWithName:(NSString *)newName;

// Accessor functions
-(int)nodeId;
-(int)categoryId;
-(int)status;
-(int)folderId;
-(NSDate *)lastActiveDate;
-(NSString *)name;
-(NSString *)description;

-(void)setNodeId:(int)newNodeId;
-(void)setCategoryId:(int)newCategoryId;
-(void)setStatus:(int)newStatus;
-(void)setFolderId:(int)newFolderId;
-(void)setLastActiveDate:(NSDate *)newLastActiveDate;
-(void)setName:(NSString *)newName;
-(void)setDescription:(NSString *)newDescription;
@end
