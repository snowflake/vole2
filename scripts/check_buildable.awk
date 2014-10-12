#!/usr/bin/awk -f

# set sdkname from the command line with -v sdkname=macos10.???

# This script checks whether an Xcode with the requested SDK is capable
# of running on current version of OS X.
# (Xcode 3.2.6 is not capable of running on on Mavericks or later).
#
# The script takes no account of Xcode 4

######################

# Functions
# =========

# return the OS X minor software version
# Example: for 10.8.1 it will return 8
function get_sw_ver(){
    while(("sw_vers" | getline) > 0){
	print $0
	split($0, fields, ":");
        if(fields[1] == "ProductVersion"){
            split(fields[2],minor,".");
            return minor[2];
        }
    }
}
######################

# main program
##############

BEGIN { 
    minorversion = get_sw_ver();
    if (sdkname == "macosx10.4u" || sdkname=="macosx10.4" ||
        sdkname =="macosx10.5" ||  sdkname == "macosx10.6"){
        max_osx_minor = 8  
    }
    else {
        max_osx_minor = 99999
    }
    if( minorversion > max_osx_minor) {
        printf("Cnnnot build for SDK %s on current version of OS X\n",
               sdkname);
        exit(1);
    }
    else {
        exit 0;
    }		
		
}
