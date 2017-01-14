//
//  main.m
//  Vienna
//
//  Created by Steve on Sun Mar 14 2004.
//  Copyright (c) 2004 Steve Palmer. All rights reserved.
//  Modified by Dave Evans Thu June 18 2010

#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <asl.h>
#import "Vole.h"
// XXXX-Tempfile has declarations which may be useful in other modules
#import "XXXX-Tempfile.h"
#import "testAnotherViennaIsRunning.h"
#import "sqlite3.h"
#import "VLCheckCodeSign.h"

/* These defines are from Appkit/NSApplication.h and should
 * be kept up to date when new versions are released
 */
#define NSAppKitVersionNumber10_0 577
#define NSAppKitVersionNumber10_1 620
#define NSAppKitVersionNumber10_2 663
#define NSAppKitVersionNumber10_2_3 663.6
#define NSAppKitVersionNumber10_3 743
#define NSAppKitVersionNumber10_3_2 743.14
#define NSAppKitVersionNumber10_3_3 743.2
#define NSAppKitVersionNumber10_3_5 743.24
#define NSAppKitVersionNumber10_3_7 743.33
#define NSAppKitVersionNumber10_3_9 743.36
#define NSAppKitVersionNumber10_4 824
#define NSAppKitVersionNumber10_4_1 824.1
#define NSAppKitVersionNumber10_4_3 824.23
#define NSAppKitVersionNumber10_4_4 824.33
#define NSAppKitVersionNumber10_4_7 824.41
#define NSAppKitVersionNumber10_5 949
#define NSAppKitVersionNumber10_5_2 949.27
#define NSAppKitVersionNumber10_5_3 949.33
#define NSAppKitVersionNumber10_6 1038
#define NSAppKitVersionNumber10_7 1138
#define NSAppKitVersionNumber10_7_2 1138.23
#define NSAppKitVersionNumber10_7_3 1138.32
#define NSAppKitVersionNumber10_7_4 1138.47
#define NSAppKitVersionNumber10_8 1187
#define NSAppKitVersionNumber10_9 1265
#define NSAppKitVersionNumber10_10 1343
#define NSAppKitVersionNumber10_11 1404
#define NSAppKitVersionNumber10_12 1504


char * osx_major_minor(void); // Returns OS X version as a string. 

char * cixLocation_cstring = "cix.compulink.co.uk"; // Normal server
char * betaserver = "v4.conferencing.co.uk"; // alternate beta server
char * volecixbetaname = "volecixbeta"; // name of a file in $HOME folder to activate the beta server
int cixbetaflag=0;  // set to 1 if using cix beta

int main(int argc, const char *argv[])
{
	// int i;
	// for(i=0; i<argc; i++)
	//      printf("== arg %d == %s\n", i, argv[i]);
	
	if(argc==2){
		if(!strcmp("-m", argv[1])){
			printf("%s",marketing_version);
			exit(0);
		}
		if(!strcmp("-v",argv[1])){
			printf("Version: %s\n", marketing_version);
			printf("Checkout: %s\n",source_code_fossil_uuid);
			if(unchecked_files){
				printf("Unchecked files: %d\n",unchecked_files);
				printf("This is BAD!\n");
				printf("The checkout does not reflect the state of the sources used for the build.\n");
			}
			exit(0);
		}
		if (!strcmp("-d",argv[1])) {
			printf("%s", buildinfo_1);
			printf("Project deployment target: %d\n", 
					VOLE_DEPLOYMENT_TARGET);
			printf("%s", buildinfo_2);
			printf("SQLite version: %s\n",sqlite3_libversion());
			printf("SQLite id: %s\n", sqlite3_sourceid());
			printf("=== Runtime ===\n");
			printf("OS X version (major.minor): %s\n", osx_major_minor());
			printf("AppKit version: %f\n", NSAppKitVersionNumber);
                        printf("Foundation version: %f\n", NSFoundationVersionNumber);
			exit(0);
		}
		if(!strcmp("-b", argv[1])){
			printf("%s\n", build_uuid);
			exit(0);
		}
		if(!strcmp("-z", argv[1])){
			printf("%s\n", build_short_id);
			exit(0);
		}

		if(!strcmp("-c", argv[1])){
			printf("%s\n",source_code_fossil_uuid);
			exit(0);
 		}
		if (!strcmp("-h", argv[1]) ||
			!strcmp("-?", argv[1]) ||
			!strcmp("--help",argv[1]) ){ 
			// help requested
			printf("Usage:\n"
			       "-h     Displays this help\n"
			       "--help Displays this help\n"
			       "-?     Displays this help\n"
			       "-v     Display version (brief)\n"
			       "-d     Display version and build information (full)\n"
			       "-b     Display build UUID\n"
			       "-z     Display short build ID\n"
			       "-c     Display Fossil checkout\n"
			       "-m     Display marketing version for the build system\n"
			       "\n"
			       "Warning: If you start Vole without any of the\n"
			       "         above options it will most likely start\n"
			       "         in a strange mode. Regardless, please\n"
			       "         immediately quit Vienna.\n");
			exit(1);   
		}
		
	}
	if( testAnotherViennaIsRunning() == true ){
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		[NSApplication sharedApplication];
		[NSBundle loadNibNamed:@"checkVienna" owner:NSApp];
		[NSApp run];
		[pool drain];
	}		
// test for using the beta server
	char * home = getenv("HOME");
	if( home == NULL) {
		home="nohome";
		NSLog(@"main.c: HOME = %s", home);
	}
	else {
		char *volecixbeta;
		int res = asprintf(&volecixbeta,"%s/%s",home,volecixbetaname);
		if (res < 1){
			NSLog(@"Error in main: volecixbeta");
		} else	if( access(volecixbeta, R_OK) == 0){
			cixLocation_cstring = betaserver;
			NSLog(@"Using cix beta server at %s",cixLocation_cstring);
			cixbetaflag=1;
		}
	}
        asl_log(NULL,NULL,ASL_LEVEL_NOTICE,"Vole %s is starting\n"
                "(build: %s,\nsrc: %s,\nunchecked files: %d\n"
                "OSX: %s, Foundation: %f, Appkit: %f )",
                marketing_version,build_short_id,
                source_code_fossil_uuid,unchecked_files,
                osx_major_minor(),
                NSFoundationVersionNumber, NSAppKitVersionNumber);
        return NSApplicationMain(argc, argv);
	return 0;
}
char * osx_major_minor(){
  if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_0){
    return "before 10.0.x";
  } else if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_1){
    return "10.0.x";
  } else if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_2){
    return "10.1.x";
  } else if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_3){
    return "10.2.x";
  } else if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_4){
    return "10.3.x";
  } else  if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_5){
    return "10.4.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_6){
    return "10.5.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_7){
    return "10.6.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_8){
    return "10.7.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_9){
    return "10.8.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_10){
    return "10.9.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_11){
    return "10.10.x";
  } else   if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_12){
    return "10.11.x";
  } else   return "10.12.x or later";
  return "Unable to detemine OSX version";
}
  
  
