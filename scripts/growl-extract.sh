#!/bin/sh

# script to extract appropiate version of growl, depending on 
# OSX SDK.

growltemp=growl-temporary-extract-directory

function zipextract(){
	# Note: There are two frameworks within these zips - current and legacy
	#       This function is only extracting the current framework
	echo extracting Growl framework version ${1}
	mkdir -p /tmp/${growltemp}
	rm -rf /tmp/${growltemp}/*
	unzip ../growl/Growl-${1}-SDK.zip -d /tmp/${growltemp}
	mv /tmp/${growltemp}/Growl-${1}-SDK/Framework/Growl.framework .
	rm -rf /tmp/${growltemp}/*
	rmdir  /tmp/${growltemp}
}
### end of function zipextract ###

rm -rf Growl.framework

if [ -z "${SDK_NAME}" ]
then
	echo Error: need to set SDK_NAME 
	exit 1
fi

case ${SDK_NAME} in
	( macosx10.4      )       tar xvf growl0.7.4.tar ;;
	( macosx10.5|macosx10.6 ) tar xvzf ../growl/growl-1.2.3.tgz ;;
	( macosx10.7|macosx10.8|macosx10.9|macosx10.10|macosx10.11|macosx10.12 \
		 ) zipextract 2.0.1 ;;
	(  * ) echo "Error: Growl Extract: unknown SDK ${SDK_NAME}"; exit 1 ;;
	esac
if [ $? -ne 0 ]
then
	echo Error extracting in growl-extract.sh.
	exit 1
fi
exit 0
