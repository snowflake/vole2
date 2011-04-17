#!/bin/sh
# convert nib directories to xib
# example:
#   find . -name '*.nib' -type d -exec nibconvert.sh {} \;
#
# You will need to add the xib files to the project and delete the nib files.


echo Processing $1
ibtool $1 --upgrade --write $(basename $1 .nib).xib 
echo return code for $i was $?
# reset the 'file extension is hidden' attribute
SetFile -a e $(basename $1 .nib).xib
