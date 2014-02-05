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
#import "Vole.h"
// XXXX-Tempfile has declarations which may be useful in other modules
#import "XXXX-Tempfile.h"
#import "testAnotherViennaIsRunning.h"
#import "sqlite3.h"

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
    return NSApplicationMain(argc, argv);
	return 0;
}
