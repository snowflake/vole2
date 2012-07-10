#!/bin/sh

# script to extract appropiate version of growl, depending on 
# OSX deployment version.

rm -rf Growl.framework

if [ -z "$MACOSX_DEPLOYMENT_TARGET" ]
then
	echo Error: need to set MACOSX_DEPLOYMENT_TARGET 
	exit 1
fi
 
case $MACOSX_DEPLOYMENT_TARGET in
	( 10.4      ) tar xvf growl0.7.4.tar            ;;
	( 10.5|10.6 ) tar xvzf ../growl/growl-1.2.3.tgz ;;
	esac
if [ $? -ne 0 ]
then
	echo Error extracting in growl-extract.sh.
	exit 1
fi
