#!/bin/sh

# script to extract appropiate version of growl, depending on 
# OSX SDK.

rm -rf Growl.framework

if [ -z "${SDK_NAME}" ]
then
	echo Error: need to set SDK_NAME 
	exit 1
fi

rm -rf Growl.framework 

case ${SDK_NAME} in
	( macosx10.4      ) tar xvf growl0.7.4.tar            ;;
	( macosx10.5|macosx10.6|macosx10.7|macosx10.8 ) 
				tar xvzf ../growl/growl-1.2.3.tgz ;;
	 * ) echo "Error: Growl Extract: unknown SDK ${SDK_NAME}"; exit 1 ;;
	esac
if [ $? -ne 0 ]
then
	echo Error extracting in growl-extract.sh.
	exit 1
fi
