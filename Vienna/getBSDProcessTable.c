/* Get BSD Process Table 
* Stolen from Technical Q&A QA1123 by Dave
*/

/* Technical Q&A QA1123
Getting List of All Processes on Mac OS X
Q: How do I get a list of all processes on Mac OS X?

A: Well, that depends on how you define "process". If you want to list all
of the running applications you should use the Carbon Process Manager routine
GetNextProcess. This will return a list of all application processes,
including those running in the Carbon, Cocoa, and Classic environments.
However, this doesn't return a list of non-application (daemon) processes.

Note:
Another caveat with GetNextProcess is that it requires you to link with Carbon,
which is not an option for some programs (for example, BSD daemon processes).

You can get a list of all BSD processes, which includes daemon processes,
using the BSD sysctl routine. Code for doing this is shown in Listing 1.
When using this code you should note the following.

The returned kinfo_proc structures contain a huge amount of information about
the process, including the process ID (in kp_proc.p_pid) and the process
name (in kp_proc.p_comm).
As far as BSD is concerned all Classic applications run within a single
process.

You do not need any special privileges to make this sysctl; any user can get
a list of all processes on the system.

The UNIX Programming FAQ lists a number of alternative ways to do this. Of
these, the only approach that works on Mac OS X is exec'ing the ps command
line tool. exec'ing ps will require parsing the tool's output and will not use system resources as efficiently as Listing 1.

You can map between BSD process IDs and Process Serial Numbers using the
routines GetProcessPID and GetProcessForPID routines declared in "Processes.h".
*/

#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>

typedef struct kinfo_proc kinfo_proc;

/* static */
int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
    // Returns a list of all BSD processes on the system.  This routine
    // allocates the list and puts it in *procList and a count of the
    // number of entries in *procCount.  You are responsible for freeing
    // this list (use "free" from System framework).
    // On success, the function returns 0.
    // On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;

    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);

    *procCount = 0;

    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.

    result = NULL;
    done = false;
    do {
        assert(result == NULL);

        // Call sysctl with a NULL buffer.

        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                      NULL, &length,
                      NULL, 0);
        if (err == -1) {
            err = errno;
        }

        // Allocate an appropriately sized buffer based on the results
        // from the previous call.

        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }

        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.

        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                          result, &length,
                          NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);

    // Clean up and establish post conditions.

    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }

    assert( (err == 0) == (*procList != NULL) );

    return err;
}
/* Listing 1. Code to list all BSD processes. */

/* [Mar 5 2002] */

