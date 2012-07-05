#!/bin/sh

# create a message to be placed in vienna/files describing the file

# $1 = path to Vole command
# $2 = name of zip file
# $3 = name of file to write
# $4 = compatibility note
# $5 = status
cat > $3  << XEOF
New file $2

[File]
Filename: $2
Hotlink to download: cixfile:vienna/files:$2
Size: $(wc -c $2 | awk '{printf $1}') 
$(md5 $2)
$(openssl sha1 $2)

[Vole]
Description: Vole off-line reader for Mac OS X only
             Vole was formerly known as Vienna or Vinkix
Version: $($1 -m)
$4
$5
Packaging: A zip file containing a disk image and an OpenPGP signature
Checkout: $( $1 -c)
Build: $($1 -b)

[Built by]
Contributor: devans
Date: $(date '+%A %e %B %Y') 

[Warning]
Windows and Linux users please note that this file is not much
use to you.

[Notes]
$(lynx -dump ../NOTES/RELEASE.html)

XEOF

