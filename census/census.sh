#!/bin/sh

# a script to generate Vienna and System information, and send it
# to the conference moderator

T=temporary-file
G="grep -i Vienna"

read -p "Please enter your Cix nickname: " nick
read -p "Please enter Vienna version   : " vers

echo Cix user nickname: $nick > $T
echo Local user name: $USER >> $T
echo Vienna version: $vers >> $T
echo Script run on: `date` >> $T
echo Script version: 1.1
H=${nick}.${USER}.`hostname`.`date +%Y-%m-%dT%H:%M:%S`


echo $H
uname -a >> $T
echo >> $T
[ -x /usr/bin/xcodebuild ] && xcodebuild -version >> $T


echo >> $T
echo 'Begin system log for Vienna' >> $T
gzip -d /var/log/system.log.[0-9]*.gz | sort | $G  >> $T

bzcat /var/log/system.log.[0-9]*.bz2 |sort |  $G >> $T
cat /var/log/system.log | $G >> $T
echo 'End system log for Vienna' >> $T

cat $T | uuencode ${H}.census | pbcopy -Prefer txt
 
open "mailto:dave.evans55@googlemail.com?subject=Vienna%20census%20${H}"
