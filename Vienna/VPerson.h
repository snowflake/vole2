//
//  VPerson.h
//  Vienna
//
//  Created by Steve on 11/23/04.
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

@interface VPerson : NSObject {
	int personId;
	NSString * shortName;
	NSString * name;
	NSString * emailAddress;
	NSString * info;
	NSString * parsedInfo;
	NSImage * picture;
}

// Public functions
-(void)setName:(NSString *)newName;
-(void)setShortName:(NSString *)newShortName;
-(void)setEmailAddress:(NSString *)newEmailAddress;
-(void)setInfo:(NSString *)newInfo;
-(void)setParsedInfo:(NSString *)newParsedInfo;
-(void)setPersonId:(int)newId;
-(void)setPicture:(NSImage *)newPicture;
-(NSString *)name;
-(NSString *)shortName;
-(NSString *)emailAddress;
-(NSString *)info;
-(NSString *)parsedInfo;
-(NSImage *)picture;
-(int)personId;
-(NSComparisonResult)personCompare:(VPerson *)otherObject;
@end
