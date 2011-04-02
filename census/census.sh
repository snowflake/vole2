#!/bin/sh

# a script to generate Vienna and System information, and send it
# to the conference moderator

scriptversion=1.3

T=temporary-file
G="grep -i Vienna"

echo
echo Welcome to the Vienna census.
echo
read -p "Please enter your Cix nickname or anon: " nick
read -p "Please enter Vienna version           : " vers
if [ X$nick = X ]
then
nick=notknown
fi
if [ X$vers = X ]
then
vers=notknown
fi

echo 
read -p "Is it OK to send Y/n ? : " ok
if [ X$ok = Xn ] || [ X$ok = XN ] 
then
echo Thanks for your participation. Your data have not been sent.
exit 0
fi
echo
echo Your email app will now be opened with the To: and Subject:
echo fields already filled in. Please remember to paste your clipboard
echo into the message body and then send the message.
echo
echo There will now be a brief pause while you read this message  ...
sleep 10
echo Starting email app.


echo Cix user nickname: $nick > $T
echo Local user name: $USER >> $T
echo Vienna version: $vers >> $T
echo Script run on: `date` >> $T
echo Script version: $scriptversion  >> $T
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

echo Ignore error messages about No such file or directory
cat $T | uuencode ${H}.census | pbcopy -Prefer txt
 
open "mailto:dave.evans55@googlemail.com?subject=Vienna%20census%20${H}"
