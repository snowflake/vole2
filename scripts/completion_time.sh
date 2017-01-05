#!/bin/sh

# Script to insert current time into a plist
# $1 = key
# $2 = file



# PlistBuddy is picky about its date format, see
#        URL: https://gist.github.com/wmerrifield/668002
# 
#   Linkname: A shell script to perform the equivalent of Xcode's "Build
#          &amp; Archive" command. GitHub

date=$(date -u "+%a %b %d %T GMT %Y")

/usr/libexec/plistbuddy -x -c "add $1 date '${date}'" $2
 
