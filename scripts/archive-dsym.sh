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


buildsave_dir=${archive_dir}/vole-builds/$( ${bpd}/${executable} -z )


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

