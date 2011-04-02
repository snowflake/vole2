#!/bin/sh

# A script to generate Vienna and system log information, and send it
# to the conference moderator
# Author: devans
# Created 2011-03-02

# Note: I don't know how long bzip2 has been available on OS X
# therefore gzip is used to compress the log.
scriptversion=1.5
# send results to TO
TO='dave.evans55@googlemail.com'
T=temporary-file
G="grep -i Vienna"
# where the system logs live
L=/var/log/system.log
# where the crash reporter files live
CR=~/Library/Logs/CrashReporter
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
logger "Vienna census script version ${scriptversion} started"


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
echo '=== Begin system log for Vienna ===' >> $T
FC=`ls  ${L}.[0-9]*.gz 2>/dev/null | wc -l`
echo gzip files ${FC}
[ $FC -gt 0 ] && \
gzcat ${L}.[0-9]*.gz | sort | $G  >> $T

FC=`ls ${L}.[0-9]*.bz2 2>/dev/null | wc -l`
echo bzip files ${FC}
[ $FC -gt 0 ] && which bzcat && \
bzcat ${L}.[0-9]*.bz2 |sort |  $G >> $T

[ -f ${L} ] && cat ${L} | $G >> $T
echo '=== End system log for Vienna ===' >> $T

echo '=== Begin crash reporter filelist for Vienna ===' >> $T
FC=`ls ${CR}/Vienna_* 2>/dev/null | wc -l`
echo crash report files ${FC}
[ ${FC} -gt 0 ] && \
ls -lT ${CR}/Vienna_* >> $T
echo '=== End crash reporter filelist for Vienna ===' >> $T

# use gzip because bzip2 may not be available
cat $T | gzip  -c9| uuencode ${H}.census.gz | pbcopy -Prefer txt
 
echo
echo Your email app will now be opened with the To: and Subject:
echo fields already filled in. Please remember to paste your clipboard
echo into the message body and then send the message.
echo
echo There will now be a brief pause while you read this message  ...
sleep 10
echo Starting email app.
open "mailto:${TO}?subject=Vienna%20census%20${H}"
