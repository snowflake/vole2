#!/bin/sh

# generate the README.html file to put in the zip
# $1 = name-version
cat << XEOF
<html><head><title>README</title></head>
<!-- ======= This file is automatically generated ====== -->
<body>
<pre>
This is the zip archive for the Vole project, an Off-Line reader
for Cix.

This zip archive contains 4 files:

XEOF
printf "%-22s %s\n" "disk-image-hashes.asc" "SHA hashes of $1.dmg"
printf "%-22s %s\n" "README.html" "What you are reading now."
printf "%-22s %s\n" "$1.dmg.sig" "A detached OpenPGP signature to check the disk image."
printf "%-22s %s\n" "$1.dmg"     "A disk image containing Vole."
printf '\n\n'
printf 'Click on the disk image file "%s" to open it.\n' "$1.dmg"
printf '</pre>\n</body>\n'
