//
//  main.m
//  Vienna
//
//  Created by Steve on Sun Mar 14 2004.
//  Copyright (c) 2004 Steve Palmer. All rights reserved.
//  Modified by Dave Evans Thu June 18 2010

#import <Cocoa/Cocoa.h>
#import <stdio.h>
// XXXX-Tempfile has declarations which may be useful in other modules
#import "XXXX-Tempfile.h"
#import "testAnotherViennaIsRunning.h"
const char *sqlite3_libversion(void);
const char *sqlite3_sourceid(void);

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
		else	if(!strcmp("-v",argv[1])){
			printf("Version: %s\n", marketing_version);
			printf("Checkout: %s\n",source_code_fossil_uuid);
			if(unchecked_files){
				printf("Unchecked files: %d\n",unchecked_files);
				printf("This is BAD!\n");
				printf("The checkout does not reflect the state of the sources used for the build.\n");
			}
			exit(0);
		} else if (!strcmp("-d",argv[1])) {
			printf("%s", buildinfo);
			printf("SQLite version: %s\n",sqlite3_libversion());
			printf("SQLite id: %s\n", sqlite3_sourceid());
			exit(0);
		} else if(!strcmp("-b", argv[1])){
			printf("%s\n", build_uuid);
			exit(0);
		} else if(!strcmp("-c", argv[1])){
			printf("%s\n",source_code_fossil_uuid);
			exit(0);
 		} else if (!strcmp("-h", argv[1]) |
			   !strcmp("-?", argv[1]) |
			   !strcmp("--help",argv[1]) ) 
			  { // help requested
			printf("Usage:\n"
			       "-h     Displays this help\n"
			       "--help Displays this help\n"
			       "-?     Displays this help\n"
			       "-v     Display version (brief)\n"
			       "-d     Display version and build information (full)\n"
			       "-b     Display build UUID\n"
			       "-c     Display Fossil checkout\n"
			       "-m     Display marketing version for the build system\n"
			       "\n"
			       "Warning: If you start Vienna without any of the\n"
			       "         above options it will most likely start\n"
			       "         in a strange mode. Regardless, please\n"
			       "         immediately quit Vienna.\n");
			exit(1);   
		}
	}
	if( testAnotherViennaIsRunning() == true ){
		[NSApplication sharedApplication];
		[NSBundle loadNibNamed:@"checkVienna" owner:NSApp];
		[NSApp run];
	}		
	else    return NSApplicationMain(argc, argv);
	return 0;
}
