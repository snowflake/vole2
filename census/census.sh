#!/bin/sh

# This script requieres that the user be in the admin group

# A script to generate Vienna and system log information, and send it
# to the conference moderator
# Author: devans
# Created 2011-03-02

# use Apple version of the utilities. Avoid Macports,Fink or Darwinports
PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Note: I don't know how long bzip2 has been available on OS X
# therefore gzip is used to compress the log.
scriptversion=1.6
# send results to TO
TO='dave.evans55@googlemail.com'
T=temporary-file
which -s uuidgen
if [ $? -ne 0 ]
then
echo "An error has occurred. You do not seem to have uuidgen"
echo "It has been available since OS X 10.2 so something is amiss."
echo "Please report this error to the vienna/chatter topic"

exit 1
fi
# get the Fossil manifest
if [ -f manifest.uuid ]
then
manifest=`cat manifest.uuid`
fi
reportid=`uuidgen`
datenow=`TZ=UTC date +%Y-%m-%dT%H:%M:%S-%Z`
G="grep -i Vienna"
H=${reportid}.${datenow}

# where the system logs live
L=/var/log/system.log
# where the crash reporter files live
CR=~/Library/Logs/CrashReporter

# Check for cookies and set if required

Viennadata='/Library/Application Support/Vienna'
Cookiefile="${Viennadata}/Vienna.cookie"


if [ ! -d "${Viennadata}" ]
then
mkdir -p "${Viennadata}"
fi
if [ -f "${Cookiefile}" ]
    then 
	Cookie=`tail -1 "${Cookiefile}"`
    else
     # give the user a cookie - Yum Yum
	echo Hello new user
	echo 'Please do not delete or modify this file.' > "${Cookiefile}"
	echo 'It is used by the Vienna census and crash reporter' >> \
		"${Cookiefile}"
	echo 'to anonymously identify your Mac.' >> "${Cookiefile}"
	echo 'Please read the man page for uuidgen.' >> "${Cookiefile}"
	Cookie=`uuidgen`
	echo ${Cookie} >> "${Cookiefile}"
    fi
echo
echo Welcome to the Vienna census.
echo

read -p "Do you wish to view the documentation in your browser y/N : " docs
if [ "X${docs}" = Xy ] || [ "X${docs}" = XY ]
then
open readme.html
fi



read -p "Please enter your Cix nickname or anon: " nick
read -p "Please enter Vienna version           : " vers
if [ "X${nick}" = X ]
then
nick=notknown
fi
if [ "X${vers}" = X ]
then
vers=notknown
fi

echo 
read -p "Is it OK to send Y/n ? : " ok
if [ "X${ok}" = Xn ] || [ "X${ok}" = XN ] 
then
echo Thanks for your participation. Your data have not been sent.
exit 0
fi

logger "Vienna census script version ${scriptversion} started for report ${H}"


echo Cix user nickname: $nick > $T
echo Local user name: $USER >> $T
echo Vienna version: $vers >> $T
echo Script run on: ${datenow} >> $T
echo Script version: $scriptversion  >> $T
echo Unique report ID: ${reportid} >> $T
echo Cookie: ${Cookie} >> $T
echo Fossil manifest SHA1: ${manifest} >> $T
echo $H

uname -a >> $T
echo >> $T
echo === Begin xcodebuild === >> $T
[ -x /usr/bin/xcodebuild ] && xcodebuild -version >> $T
[ -x /usr/bin/xcode-select ]  && xcode-select -print-path >> $T
echo === End xcodebuild === >> $T

echo === Begin developer tools === >> $T
if [ -x /usr/sbin/system_profiler ]
then
system_profiler SPDeveloperToolsDataType >> $T
else
echo No system_profiler, shame >> $T
fi
echo === End developer tools === >> $T



echo >> $T
echo '=== Begin system log for Vienna ===' >> $T
FC=`ls  ${L}.[0-9]*.gz 2>/dev/null | wc -l`
echo gzip files ${FC}
[ $FC -gt 0 ] && \
gzcat ${L}.[0-9]*.gz |  $G  >> $T

FC=`ls ${L}.[0-9]*.bz2 2>/dev/null | wc -l`
echo bzip files ${FC}
[ $FC -gt 0 ] && which bzcat && \
bzcat ${L}.[0-9]*.bz2  |  $G >> $T

[ -f ${L} ] && cat ${L} | $G >> $T
echo '=== End system log for Vienna ===' >> $T

echo '=== Begin crash reporter filelist for Vienna ===' >> $T
FC=`ls ${CR}/Vienna_* 2>/dev/null | wc -l`
echo crash report files ${FC}
[ ${FC} -gt 0 ] && \
ls -lT ${CR}/Vienna_* >> $T
echo '=== End crash reporter filelist for Vienna ===' >> $T

# use gzip because bzip2 may not be available
cat $T | gzip  -c9| uuencode ${H}.vnr.gz | pbcopy -Prefer txt
 
echo
echo Your email app will now be opened with the To: and Subject:
echo fields already filled in. Please remember to paste your clipboard
echo into the message body and then send the message. Please do not
echo alter the message header or body in any way.
echo
echo There will now be a brief pause while you read this message  ...
sleep 10
echo Starting email app.
open "mailto:${TO}?subject=Vienna%20census%20${H}"
