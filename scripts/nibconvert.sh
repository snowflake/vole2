#!/bin/sh
# convert nib directories to xib
# example:
#   find . -name '*.nib' -type d -exec nibconvert.sh {} \;
#
# You will need to add the xib files to the project and delete the nib files.


echo '----------------------' Processing $1
/Xcode3.2.6/usr/bin/ibtool $1 --upgrade --errors --warnings \
	--notices --output-format human-readable-text \
	--write $(basename $1 .nib).xib 
echo return code for $1 was $?
# reset the 'file extension is hidden' attribute
SetFile -a e $(basename $1 .nib).xib
