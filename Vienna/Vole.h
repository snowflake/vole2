// This header file is partly taken from JSONKIT.
// It should be included in all headers that use Cocoa, Appkit or Foundation.
// (DJE)

//
//  JSONKit.h
//  http://github.com/johnezang/JSONKit
//  Dual licensed under either the terms of the BSD License, or alternatively
//  under the terms of the Apache License, Version 2.0, as specified below.
//

/*
 Copyright (c) 2011, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 Copyright 2011 John Engelhart
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

// Define NSInteger and NSUInteger
// For Mac OS X < 10.5.
#ifndef   NSINTEGER_DEFINED
#define   NSINTEGER_DEFINED
#if       defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
typedef long           NSInteger;
typedef unsigned long  NSUInteger;
#define NSIntegerMin   LONG_MIN
#define NSIntegerMax   LONG_MAX
#define NSUIntegerMax  ULONG_MAX
#else  // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
typedef int            NSInteger;
typedef unsigned int   NSUInteger;
#define NSIntegerMin   INT_MIN
#define NSIntegerMax   INT_MAX
#define NSUIntegerMax  UINT_MAX
#endif // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
#endif // NSINTEGER_DEFINED

// This is from CGBase.h
#ifndef CGFLOAT_DEFINED
#include <stdbool.h>
#include <stddef.h>
#include <float.h>
/* Definition of `CGFLOAT_TYPE', `CGFLOAT_IS_DOUBLE', `CGFLOAT_MIN', and
   `CGFLOAT_MAX'. */

#if defined(__LP64__) && __LP64__
# define CGFLOAT_TYPE double
# define CGFLOAT_IS_DOUBLE 1
# define CGFLOAT_MIN DBL_MIN
# define CGFLOAT_MAX DBL_MAX
#else
# define CGFLOAT_TYPE float
# define CGFLOAT_IS_DOUBLE 0
# define CGFLOAT_MIN FLT_MIN
# define CGFLOAT_MAX FLT_MAX
#endif

/* Definition of the `CGFloat' type and `CGFLOAT_DEFINED'. */

typedef CGFLOAT_TYPE CGFloat;
#define CGFLOAT_DEFINED 1

#endif // CGFLOAT_DEFINED


// AppKit version numbers (From AppKit Release Notes for OSX 10.9
// and 10.11 Appkit release notes

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif

#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif

#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1038
#endif

#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1138
#endif

#ifndef NSAppKitVersionNumber10_8
#define NSAppKitVersionNumber10_8 1187
#endif

#ifndef NSAppKitVersionNumber10_9
#define NSAppKitVersionNumber10_9 1265
#endif

#ifndef NSAppKitVersionNumber10_10
#define NSAppKitVersionNumber10_10 1343
#endif

#ifndef NSAppKitVersionNumber10_10_2
#define NSAppKitVersionNumber10_10_2 1344
#endif

#ifndef NSAppKitVersionNumber10_10_3
#define NSAppKitVersionNumber10_10_3 1347
#endif

#ifndef NSAppKitVersionNumber10_10_4
#define NSAppKitVersionNumber10_10_4 1348
#endif

#ifndef NSAppKitVersionNumber10_10_5
#define NSAppKitVersionNumber10_10_5 1348
#endif

#ifndef NSAppKitVersionNumber10_10_Max
#define NSAppKitVersionNumber10_10_Max 1349
#endif

//  end of Appkit versions

#ifndef VOLE_DEPLOYMENT_TARGET
#error VOLE_DEPLOYMENT_TARGET must be a project preprocessor definition 
#endif

// 2 digits major, 3 digits minor
#define VOLE_MACOSX_10_4  10004
#define VOLE_MACOSX_10_5  10005
#define VOLE_MACOSX_10_6  10006
#define VOLE_MACOSX_10_7  10007
#define VOLE_MACOSX_10_8  10008
#define VOLE_MACOSX_10_9  10009
#define VOLE_MACOSX_10_10 10010
#define VOLE_MACOSX_10_11 10011
#define VOLE_MACOSX_10_12 10012

// declarations for main.m and VoleBuildInfo
extern char vole_build_info[];
extern char vole_vcs_changes[];


//
//  VOLE2 is defined (or not) 
//  in Config/*.xcconfig files.
//
// The name of the database

#ifdef VOLE2
#define DBNAME @"~/Library/Vienna/database_utf8.db"
#define VOLE_ALPHA_STRING @"   <<<<  VOLE 2 ALPHA  >>>>"
#define VoleDatabaseStringEncoding NSUTF8StringEncoding
#else
// Classic vole 1
#define DBNAME @"~/Library/Vienna/database3.db"
#define VoleDatabaseStringEncoding NSWindowsCP1252StringEncoding
#endif
