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

int main(int argc, const char *argv[])
{
	// int i;
	// for(i=0; i<argc; i++)
	//      printf("== arg %d == %s\n", i, argv[i]);

	if(argc==2){
		if(!strcmp("-v",argv[1])){
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
			exit(0);
		} else if(!strcmp("-b", argv[1])){
			printf("%s\n", build_uuid);
			exit(0);
		} else if(!strcmp("-c", argv[1])){
			printf("%s\n",source_code_fossil_uuid);
			exit(0);
 		} else if (!strcmp("-h", argv[1])){ // help requested
			printf("Usage:\n");
			printf("-v   Display version (brief)\n");
			printf("-d   Display version and build information (full)\n");
			printf("-b   Display build UUID\n");
			printf("-c   Display Fossil checkin\n");
			exit(1);   
		}
	}
    return NSApplicationMain(argc, argv);
}
