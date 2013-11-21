//
//  Signatures.h
//  Vienna
//
//  Created by Steve on Mon May 03 2004.
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

@interface Signatures : NSObject {
	NSMutableDictionary * signatures;
}

// Public functions
+(Signatures *)defaultSignatures;
-(NSArray *)signatureTitles;
-(NSString *)signatureForTitle:(NSString *)title;
-(void)addSignature:(NSString *)title withText:(NSString *)withText;
-(void)removeSignature:(NSString *)title;
@end
