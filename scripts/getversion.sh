#!/bin/sh
PATH=${DEVELOPER_DIR}/usr/bin:${PATH}


echo 'getversion.sh is not used anymore, use versionscript.sh marketingversion'
exit 1
# get the version from Info.plist

# # agvtool does not work with multiple projects in the same directory
#agvtool mvers |  tr '"' '|' \
#	| awk  'BEGIN { FS="|" } /Found CFBundle/ { printf "%s", $2 }'

# Use PlistBuddy instead
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist
