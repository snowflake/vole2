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
	if(argc==2){
		if(!strcmp("-v",argv[1])){
			printf("UUID: %s\n",source_code_fossil_uuid);
			if(unchecked_files){
				printf("Unchecked files: %d\n",unchecked_files);
				printf("This is BAD!\n");
				printf("The UUID does not reflect the state of the sources used for the build.\n");
			}
			exit(0);
		} else if (!strcmp("-d",argv[1])) {
			printf("%s", buildinfo);
			exit(0);
		} else { // unrecognised option
			printf("Usage:\n");
			printf("-v   Display version (brief)\n");
			printf("-d   Display version and build information (full)\n");
			exit(1);
		}
	}
    return NSApplicationMain(argc, argv);
}
