#!/bin/sh

# Script to insert current time into a plist
# $1 = file



# PlistBuddy is picky about its date format, see
#        URL: https://gist.github.com/wmerrifield/668002
# 
#   Linkname: A shell script to perform the equivalent of Xcode's "Build
#          &amp; Archive" command. GitHub

# Get seconds since the Epoch
SSTE=$(date -u +%s)

date=$(date -u -r ${SSTE} "+%a %b %d %T GMT %Y")

/usr/libexec/plistbuddy -x -c "add :BuildCompletionTime date '${date}'" $1
 
/usr/libexec/plistbuddy -x -c "add :BuildCompletionTimeSeconds integer ${SSTE}" $1
