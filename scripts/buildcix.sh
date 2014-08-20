#!/bin/sh

# create a message to be placed in vienna/files describing the file

# $1 = path to Vole command
# $2 = name of zip file
# $3 = name of file to write
# $4 = compatibility note
# $5 = status
# $6 = deployment target (10.4 10.5 etc)
# $7 = build archs (ppc i386 x86_64)
# $8 = SDK (macosx10.4 etc )
deploy="${6}"
archs="${7}"
sdk="${8}"
shortbuild="${9}"

function list_minimum_osx(){
printf "Minimum OS X required: "
case ${deploy} in 
	10.4)   printf "10.4 Tiger and later";;
	10.5)   printf "10.5 Leopard and later";;
	10.6)   printf "10.6 Snow Leopard and later";;
	10.6.8) printf '10.6.8 Snow Leopard (last version) and later';;
	10.7)   printf "10.7 Lion and later";;
	10.8)   printf "10.8 Mountain Lion and later";;
	10.9)   printf "10.9 Mavericks and later";;
        10.10)  printf "10.10 Yosemite and later";;
        *         )  printf "Unknown";;
esac
}

function list_archs(){
printf "Runs On:"
native=No
for i in ${archs}
do
case $i in
	ppc)    ppc=" PowerPC" ;;
	i386)   i32=" Intel-32-bit" ; i64=" Intel-64-bit" ;;
	x86_64) i64=" Intel-64-bit" ; native=Yes ;;
esac
done
printf "%s%s%s\n" "${ppc}" "${i32}" "${i64}"
printf "Native Intel-64-bit: %s" $native
}
##### end of function #####
function sandpit_warning(){
if [ $sandpit = sandpit ]
then
cat <<SPEOF
[warning]
This release of Vole is in the Sandpit for good reason. It is for 
testing. It could be unstable or crash. Some features may not be fully
working. We have put a reasonable amount of work into making it run
properly but it is impossible to predict all possible usage scenarios.
If you see something not working as it should, please report it
in the sandpit topic.
SPEOF
fi
}
#####

sandpit=NotSet
while [ $sandpit = NotSet ]
do 
  read -p 'Is this release for the Sandpit? (y/n): ' rel
  case $rel in
      [Yy] ) sandpit=sandpit ; break ;;
      [Nn] ) sandpit=files ; break ;;
  esac
done

cat > $3  << XEOF
New file $2

[File]
Filename: $2
Hotlink to download (via Cix): cixfile:vienna/${sandpit}:$2
Hotlink to download (via browser):
(For download via browser, click on the hotlink.
   When the browser window opens, click on the File menu at the
   top left of the window, immediately below the filename.
   This is not the same as the File menu in the menubar.)
Size: $(wc -c $2 | awk '{printf $1}') 
$(/sbin/md5 $2)
$(openssl sha1 $2)

[Vole]
Description: Vole off-line reader for Mac OS X only.
             Vole was formerly known as Vienna or Vinkix
Version: $($1 -m)
$(list_minimum_osx)
$(list_archs)
$5
Packaging: A zip file containing a disk image and an OpenPGP signature
SDK: ${sdk}
Checkout: $( $1 -c)
Build: $($1 -b)
Short Build: $( $1 -z)
$(dwarfdump --uuid $1 | awk '{ print $1, $2, $3 }')

[Built by]
Contributor: devans
Date: $(date '+%A %e %B %Y') 

[Warning]
***********************************************************************
To avoid disappointment and a wasted download, please check the 
Minimum OS X Required and Runs On fields above to make sure
that this download of Vole will be compatible with your system.
 
Previous versions of Vole/Vinkix/Vienna were compatible with everything
from Tiger upwards. This is no longer the case. We will probably
have several versions of Vole available optimised for different
systems.  
***********************************************************************

$(sandpit_warning)

[Notes]
$(/opt/local/bin/lynx -dump ../NOTES/RELEASE.html)

XEOF

