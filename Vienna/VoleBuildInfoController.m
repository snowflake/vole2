//  Copyright (c) 2014 Dave Evans. All rights reserved.
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

#import "VoleBuildInfoController.h"

@implementation VoleBuildInfoController




-( char *)  getSysctl: (char *) sysctl {
	static char buff[50];
	size_t oldlen = sizeof(buff) - 1;
	size_t newlen = 0;
	int retcode = sysctlbyname(sysctl, buff, &oldlen, NULL, newlen);
	if(retcode == 0)
		return buff;
	else
		return "sysctlbyname failed";
}

-( char *) getCurrentArch {
#if defined(__i386__)
#   define VOLE_ARCH "i386"
#elif defined(__x86_64__)
#   define VOLE_ARCH "x86_64"
#elif defined(__ppc__)
#   define VOLE_ARCH "ppc"
#elif defined(__ppc64__)
#   define VOLE_ARCH "ppc64"
#else
#   define VOLE_ARCH "Unknown"
#endif
	return VOLE_ARCH;	
	
}



/* init
 * Just init the activity window.
 */
-(id)init
{
	if( ! [super initWithWindowNibName:@"VoleBuildInfo"])
		return nil;
	return self;
}

/* windowDidLoad
 * Set the font for the activity viewer
 */
-(void)windowDidLoad
{
	NSFont * font = [NSFont userFixedPitchFontOfSize:12];
	
	[textView setFont:font];
	[textView setContinuousSpellCheckingEnabled:NO];
	[textView setEditable:NO];
	[textView setString:[self voleStatusReport]];
}

-(IBAction)voleCpyToPasteboard:(id)sender {
    (void) sender;
    NSString * sr = [self voleStatusReport];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes: [NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setString:sr forType:NSStringPboardType];
    [textView setString:sr];
    
}

-(NSString *)voleStatusReport {
	NSString * bundleLocation = [[NSBundle mainBundle] bundlePath ];
	NSString *report = [NSString stringWithFormat:
						@"=== Vole Status Report ===\n"
						"Date generated: %@\n"
						"\n"
						"[Vole Runtime]\n"
						"Location: %@\n"
						"%@" // OSX versions
						"Hardware Machine: %s\n"
						"Current Architecture: %s\n"
						"AppKit Version: %.12g\n"
						"Foundation Version: %.12g\n"
						"\n"
						"%s" // build
						"%s",  // unchecked files
						[[NSDate date] description],
						bundleLocation ? bundleLocation : @"Unknown", // Location
						[self softwareVersion],
						[self getSysctl:"hw.machine"],
						[self getCurrentArch],
						NSAppKitVersionNumber,
						NSFoundationVersionNumber,
						vole_build_info,
						vole_vcs_changes];
	
	return report;

}

-(NSString *) softwareVersion {
	NSDictionary * versionDict;
	NSString * server = @"";
	versionDict = [NSDictionary dictionaryWithContentsOfFile:
				   @"/System/Library/CoreServices/SystemVersion.plist"];
	if(versionDict)
		server	= @"";
	else if((versionDict=[NSDictionary dictionaryWithContentsOfFile:
						  @"/System/Library/CoreServices/ServerVersion.plist"]))
		server=@"Server ";
	else 
		return @"OS X Version: Unknown (No plist)\n";
	NSString *osxversion = [versionDict valueForKey:@"ProductUserVisibleVersion"];
	NSString *osxbuild   = [versionDict valueForKey:@"ProductBuildVersion"];
	
	return [NSString stringWithFormat:@"OS X %@Version: %@\nOS X Build: %@\n",
			server,
			osxversion ? osxversion : @"Unknown",
			osxbuild   ? osxbuild   : @"Unknown" ];
	
}
@end
