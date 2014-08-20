#!/bin/sh
set -e
# copy the zip file to Google Drive directory with an insanely long filename

GOOGLEDRIVE=~/Google\ Drive

# Parameters 
# $1 = command string (copy,longfilename)
# $2 = location of Vole binary within the App bundle (or a dummy variable)
# $3 = zip file name 



command="${1}"
binary="${2}"
zipin="${3}"

#####
function doshortcopy(){
	echo Shortcopy "${zipin}" to "${GOOGLEDRIVE}"
	cp -nv "${zipin}" "${GOOGLEDRIVE}"
	exit $?
}
#####


copy=0
lfn=0

case ${command} in
	(copy) copy=1 ;;
	(longfilename) lfn=1 ;;
        (shortcopy ) doshortcopy; exit $? ;;
	(*)echo 'Invalid command'; exit 1 ;;
esac

marketingversion=$( "${binary}" -m)
build=$( "${binary}" -z)
checkout=$( "${binary}" -c )

sdknum=${build:16}

case $sdknum in 
	( 4 ) sdk=TIGER ;;
	( 5 ) sdk=LEOPA ;;
	( 6 ) sdk=SNOWL ;;
	( 7 ) sdk=LION ;;
	( 8 ) sdk=MLION ;;
	( 9 ) sdk=MAVER ;;
	( 10 )sdk=YOSEM ;;
        ( *  )echo 'Unknown SDK, script failed!'; exit 1;;
esac

filename=Vole-${sdk}-${marketingversion}-${build}-${checkout:0:10}.zip

if [ $lfn -eq 1 ]
then
	printf 'Filename: %s\n' ${filename}
	exit 0
fi
    
if [ $copy -eq 1 ]
then
	printf 'Will do copy\n'
	cp -nv ${zipin} "${GOOGLEDRIVE}"/"${filename}"
	exit $?
fi
