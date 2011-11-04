#!/bin/sh

# create a message to be placed in vienna/files describing the file

# $1 = path to Vienna command
# $2 = name of zip file
# $3 = name of file to write
# $4 = compatibility note
# $5 = status
cat > $3  << XEOF
New file $2

Filename: $2
Description: Vienna off-line reader
Hotlink to download: cixfile:vienna/files:$2
Size: $(wc -c $2 | awk '{printf $1}') 
Version: $($1 -m)
$5

Contributor: devans
Date: $(date '+%A %e %B %Y') 

$4
Packaging: A zip file containing a disk image and an OpenPGP signature
$(md5 $2)

Checkout: $( $1 -c)
Build: $($1 -b)

Notes:
$(lynx -dump ../NOTES/RELEASE.html)

XEOF

