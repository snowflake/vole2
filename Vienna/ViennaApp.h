//
//  ViennaApp.h
//  Vienna
//
//  Created by Steve on Tue Jul 06 2004.
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
#import "Folder.h"

@interface ViennaApp : NSApplication {
}
-(void)handleGetMessages:(NSScriptCommand *)name;
-(NSString *)applicationVersion;
-(NSInteger)checkFrequency;
-(void)setCheckFrequency:(NSInteger)newFrequency;
-(void)internalSetCheckFrequency:(NSInteger)newFrequency;
-(NSColor *)quoteColour;
-(void)setQuoteColour:(NSColor *)newQuoteColour;
-(void)internalSetQuoteColour:(NSColor *)newQuoteColour;
-(NSColor *)priorityColour;
-(void)setPriorityColour:(NSColor *)newPriorityColour;
-(void)internalSetPriorityColour:(NSColor *)newPriorityColour;
-(NSColor *)ignoredColour;
-(void)setIgnoredColour:(NSColor *)newIgnoredColour;
-(void)internalSetIgnoredColour:(NSColor *)newIgnoredColour;
-(Folder *)currentFolder;
-(NSArray *)folders;
-(BOOL)isConnecting;
-(NSInteger)unreadCount;
@end

