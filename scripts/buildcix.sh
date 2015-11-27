#!/bin/sh
set -e
# create a message to be placed in vienna/files describing the file

# $1 = path to Vole command
# $2 = name of zip file
# $3 = name of file to write
# $4 = compatibility note
# $5 = status
# $6 = deployment target (10.4 10.5 etc)
# $7 = build archs (ppc i386 x86_64)
# $8 = SDK (macosx10.4 etc )
binary="${1}"
zipfile="${2}"
cixfile="${3}"
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
function print_md5(){
	/sbin/md5 $1 | /usr/bin/awk '{print "MD5:", $4}'
	}
function print_sha1(){
	/usr/bin/openssl sha1 $1 | awk '{print "SHA1:", $2}'
	}
###################################
function webdownload(){
printf 'Web:\n'
printf 'Info: To download the file, open your browser on the Web link above,\n'
printf '      then hover your mouse pointer at the top of the page. A tool\n'
printf '      bar of options will appear and one of them will download the file.\n'
}
##################################
function copytogoogle(){
read -p 'Is this stable release to be copied to Google y/n: ' google
case "${google}" in
	( [Yy] ) echo copy to google2 ;
		/bin/sh ../scripts/copy-to-google.sh shortcopy dummy "${zipfile}" ;;
	( * ) echo Not copying to Google;;
esac

}

###################################
function display_file_info(){
printf '[File]\n'
if [ $sandpit = files ]
then
   printf 'Filename: %s\n' ${1}
   printf 'Hotlink To Download: cix:vienna/files:%s\n' ${1}
   case ${google} in
	([Yy]) webdownload ;;
   esac
else
   sh ../scripts/copy-to-google.sh longfilename ${binary}
   webdownload
fi
} 
################################### end of functions #####################
sandpit=NotSet
while [ $sandpit = NotSet ]
do 
  read -p 'Is this release for the Sandpit? (y/n): ' rel
  case $rel in
      [Yy] ) sandpit=sandpit 
	     sh ../scripts/copy-to-google.sh copy "${binary}" \
				"${zipfile}" ;;
      [Nn] ) sandpit=files ; echo copy to google; copytogoogle ;;
  esac
done


cat > $3  << XEOF

Date: $(date)

$(display_file_info ${2})
Size: $(wc -c $2 | awk '{printf $1}') 
$(print_md5  $2)
$(print_sha1 $2)

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
For release notes, please visit:
https://chiselapp.com/user/vinkix/repository/olrcix/wiki?name=RI

XEOF

