#!/bin/sh

# a script to generate Vienna and System information, and send it
# to the conference moderator

T=temporary-file
G="grep -i Vienna"

if [ X$1 = X ]
then
	echo Usage: sh census.sh '<Your cix nickname>'
	echo Example: sh census.sh devans
	exit 1
fi

echo Cix user nickname: $1 > $T
echo Script run on: `date` >> $T

uname -a >> $T
echo >> $T
[ -x /usr/bin/xcodebuild ] && xcodebuild -version >> $T

echo >> $T
gzip -d /var/log/system.log.[0-9]*.gz | sort | $G  >> $T

bzcat /var/log/system.log.[0-9]*.bz2 |sort |  $G >> $T
cat /var/log/system.log | $G >> $T

