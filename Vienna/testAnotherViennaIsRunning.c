/*
 *  testAnotherViennaIsRunning.c
 *  Vienna
 *
 *  Created by David Evans on 25/11/2011.
 *  Copyright 2011 David Evans All rights reserved.
 *
 */
#import <syslog.h>
#import <assert.h>
#import <errno.h>
#import <stdbool.h>
#import <stdlib.h>
#import <stdio.h>
#import <unistd.h>
#import <string.h>
#import "testAnotherViennaIsRunning.h"
#import "getBSDProcessTable.h"
bool
testAnotherViennaIsRunning(void){
	bool retcode = false;
	static kinfo_proc *p, *sv;
	size_t   i, procCount;
	int result = GetBSDProcessList( &p, &procCount);
	if(result == 0){
		sv = p;
		pid_t ourpid = getpid();
		for(i=0;i<procCount;i++, p++) {
			if(ourpid == p->kp_proc.p_pid) {
				// it's us
				continue;
			}
			if(	! strcmp("Vinkix",p->kp_proc.p_comm)){
				// Another process with our name 
				retcode = true;
				break;
			}
		}
		free(sv);
		return retcode;
	}
	else {
		// Error in fetching the process table
		syslog(LOG_ERR, "%m fetching process table in %s",
			   "testAnotherViennaIsRunning.c");
		exit(1);
	}
}
