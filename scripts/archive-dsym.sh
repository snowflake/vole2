#!/bin/sh
set -e

# This script archives the build products in directories referenced
# by build-id and executable UUIDs. This is for lldb

# $1 = build products directory ( eg ~/Vienna-source/Vienna-build/mavericks
bpd=$1

function get_uuids(){
dwarfdump --uuid ${bpd}/${executable} | awk '{ print $2}'
}

archive_dir=${HOME}/Archive-dsyms
uuid_dir=${archive_dir}/UUIDs
executable=Vole.app/Contents/MacOS/Vole

build=$( ${bpd}/${executable} -z)
# sdknum=${build:16} ## old code ##
sdknum=$(/usr/libexec/plistbuddy -c "print :SDKName" \
	${bpd}/Vole.app/Contents/Resources/VoleInfo.plist)
echo Using SDK ${sdknum}

case $sdknum in
	( macosx10.4 ) sdk=TIGER ;;
	( macosx10.5 ) sdk=LEOPD ;;
	( macosx10.6 ) sdk=SNOWL ;;
	( macosx10.7 ) sdk=LION  ;;
	( macosx10.8 ) sdk=MLION ;;
	( macosx10.9 ) sdk=MAVER ;;
	( macosx10.10 ) sdk=YOSEM ;;
        ( macosx10.11 ) sdk=ELCAP ;;
        ( macosx10.12 ) sdk=SIERA ;;
	( * ) echo 'Unknown SDK'; exit 1 ;;
esac

buildsave_dir=${archive_dir}/vole-builds/${sdk}/${build}


[ ${1} ] 
[ -d ${bpd}/Vole.app ] 

echo ${buildsave_dir}
mkdir -p ${buildsave_dir}
mkdir -p ${uuid_dir}

for i in ${bpd}/*
do
echo Copying $i
ditto $i ${buildsave_dir}/$(basename $i)
done

for i in $(get_uuids)
do
echo UUID $i
ln -sfh ${buildsave_dir} ${uuid_dir}/${i}
done

