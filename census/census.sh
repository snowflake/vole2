#!/bin/sh

# This script requires that the user be in the admin group to send a log report

# A script to generate Vienna and system log information, and send it
# to the conference moderator
# Author: devans
# Created 2011-03-02

scriptversion=1.7


# use Apple version of the utilities. Avoid Macports,Fink or Darwinports
PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Note: I don't know how long bzip2 has been available on OS X
# therefore gzip is used to compress the log.
# send results to TO
TO='dave.evans55@googlemail.com'
T=/tmp/vlcr.${USER}.report.temporary.txt

FULLDOC=/tmp/vlcr.${USER}.fulldoc.html
QSGDOC=/tmp/vlcr.${USER}.qsgdoc.html

# 0 if nickname not set 
nickset=0

# get the Fossil manifest
manifest='Not found'
if [ -f manifest.uuid ]
then
manifest=`cat manifest.uuid`
fi

clear
echo
echo
echo "Vienna census, crash and log reporter version ${scriptversion}"  
echo 

############### nickname setting function #######
function cix_nick() {
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
nickset=1
}
############### end of nickanme setting #########



################ begin reporter function ##################
function reporter () {
which -s uuidgen
if [ $? -ne 0 ]
then
echo "An error has occurred. You do not seem to have uuidgen."
echo "It has been available since OS X 10.2 so something is amiss."
echo "Please report this error to the vienna/chatter topic."
echo "You are welcome to browse the documentation."
echo 
return  1
fi
reportid=`uuidgen`
datenow=`TZ=UTC date +%Y-%m-%dT%H:%M:%SZ`
G="grep -i Vienna"
H=${reportid}.${datenow}

# where the system logs live
L=/var/log/system.log

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


# ask the user for nickname if never set
if [ "${nickset}" -eq 0 ] ; then cix_nick ; fi

echo Cix user nickname: $nick > $T
echo Local user name: $USER >> $T
echo Vienna version: $vers >> $T
echo Report type: ${REPORT_TYPE} >> $T
echo Script run on: ${datenow} >> $T
echo Script version: $scriptversion  >> $T
echo Unique report ID: ${reportid} >> $T
echo Cookie: ${Cookie} >> $T
echo Fossil manifest SHA1: ${manifest} >> $T
echo >> $T
echo '=== Begin uname ===' >> $T
uname -a >> $T
echo '=== End uname ===' >> $T
echo >> $T
echo === Begin Mac OS X version === >> $T
sw_vers >> $T
echo === End Mac OS X version === >> $T

echo >> $T
echo === Begin xcodebuild === >> $T
[ -x /usr/bin/xcodebuild ] && xcodebuild -version >> $T
[ -x /usr/bin/xcode-select ]  && xcode-select -print-path >> $T
echo === End xcodebuild === >> $T

echo >> $T

echo === Begin developer tools === >> $T
if [ -x /usr/sbin/system_profiler ]
then
system_profiler SPDeveloperToolsDataType >> $T
else
echo No system_profiler, shame >> $T
fi
echo === End developer tools === >> $T



echo >> $T
if [ X${REPORT_TYPE} = XLog ]
then
echo '=== Begin system log files count ===' >> $T
GFC=`ls  ${L}.[0-9]*.gz 2>/dev/null | wc -l`
echo System log gzip files: ${GFC} | tee -a $T
BFC=`ls ${L}.[0-9]*.bz2 2>/dev/null | wc -l`
echo System log bzip files: ${BFC} | tee -a $T
echo === End system log files count === >> $T

echo >> $T
echo '=== Begin system log for Vienna ===' >> $T
[ $GFC -gt 0 ] && \
gzcat ${L}.[0-9]*.gz |  $G  >> $T

[ $BFC -gt 0 ] && which -s bzcat && \
bzcat ${L}.[0-9]*.bz2  |  $G >> $T

[ -f ${L} ] && cat ${L} | $G >> $T
echo '=== End system log for Vienna ===' >> $T
fi  # end of if for report type log


echo >> $T
echo '=*= End of report =*=' >> $T



# because the administrator does not have permission to access other
# users files, the crash reporter filelist has been deleted

echo 
read -p "Is it OK to send the report [Y/n] ? : " ok
if [ "X${ok}" = Xn ] || [ "X${ok}" = XN ] 
then
echo Thanks for your participation. Your report has not been sent.
echo You can find the text of the report that would have been 
echo sent in the file "${T}"
return 0
echo
fi




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
logger "Vienna census script version ${scriptversion} sending report ${H}"
echo Starting email app.
open "mailto:${TO}?subject=Vienna%20census%20${H}"

} 
################ end of reporter function ####################

############# begin full documentation function ##############

function full_docs () {

cat > ${FULLDOC} << "END_OF_FULL_DOC_zhqa"
<!-- Full documentation for Vienna crash reporter is now
stored in the script -->
<head>
<title>The Vienna census - how to participate</title>
</head>

<body>
<pre>
It's census time here in the Vienna conference.  This is
the one you cannot afford to miss! Your  participation
will be most welcome and it will help the Vienna developers
in the future development of Vienna.

What's being collected?  - see below

How to participate.
------------------
Download cixfile:vienna/files:census.zip
(It's tiny, < 5k)

Open Vienna and navigate to Vienna -> About Vienna
Make a note of Vienna version information, N.N.NN (NNNN)

Create an empty folder in your home folder and name it
"census". Unzip the zip file into it.

If you have any work that you have copied to the clipboard,
please save it now.

Open /Applications/Utilities/Terminal

Yes, I know it is the command line. I'm very sorry
for those of you who are averse to the command line, but
this is the simplest way for me to implement a simple
survey.

In Terminal window type:

      cd census
      sh census.sh

You will be asked if you wish to view the documentation in
your browser. Answer Y or N.

A prompt will appear. Please answer the question
with your Cix nickname.

Another prompt will appear. Please answer the question
with the Vienna version information or "none" if you do
not have Vienna..

You will be asked if you wish to send the census data.
Answer Y (default) or N

When you have done that, your default email program
will open with the To: and Subject: fields already
filled in. 

We are almost done. A tiny program has copied the
census data to your clipboard. 

Now for the important step!

=== Paste the clipboard into the message window. ===

Take care not to disturb the census data.

Now send the message.

That's it. Job done. Simples. Thanks for your participation.
It will help us in the future development of Vienna.
----

Problems
--------
When pasting the clipboard into Thunderbird, it sometimes comes up with
a message "Found an attachment keyword XX". It is trying to be too
clever. Close the yellow window by clicking on the litte X icon
on the right and send the message as usual.

For the security conscious.
---------------------------

Q: What information is being gathered?

A:
Most of this information is gathered by the script automatically.
Basic information about your Mac.
Your Vienna version.
Whether you have the development system installed and which
version.
Your Mac's hostname.
Your cix nickname and login name on your Mac.
System log messages that relate to Vienna.
A list of Crash Reporter files that relate to Vienna. We don't collect
the files at the moment..

Q: How do I find out what is being sent?

A:
Read the file temporary-file in the census directory.
Review the script census.sh.

Q: What programs are used to create the census.

A: census.sh - a small Bash shell script available for review by anyone.
Standard system utilities such as gzip bzcat pbcopy grep uuencode
hostname uname uuidgen and (if it exists) xcodebuild.
Your default email application.

Q: Why is the census data sent in BASE64 or UUencoded form?

A: To prevent long lines from getting mangled. The data are also
compressed.

Q: Why are the system log messages relating to Vienna being gathered?

A: I want to see whether you get the same messages that I get, or
any that I have not seen before.
---

Privacy Policy
--------------
Your personal data (email address, login name, cix nickname, hostname)
will not be shared with anyone.

You do not have to give your cix nickname to participate but I would
much prefer that you do give it.

The script will install a small cookie in 
~/Library/Vienna/Vienna-census.cookie
It contains a UUID. Please see http://en.wikipedia.org/wiki/UUID
Please do not delete this file. It is used to identify your Mac
anonymously in the event you send more than one report. It will
also be used in a forthcoming crash reporter.

</pre>
</body>




END_OF_FULL_DOC_zhqa
if [ $? -ne 0 ] 
then
echo an error has occured in generating the documentation file
return 1
fi
open ${FULLDOC}
}
############ end of full_docs function ##############

########### start of send_email function ############

function send_email () {
cat << END_OF_EMAIL
Your email application will open in a new window
with the To: and Subject: headers filled in.
Feel free to change the Subject:, leaving the word
Vienna in there somewhere.
END_OF_EMAIL

open "mailto:${TO}?subject=Vienna%20vlcr"

}
########### end of send_email function #############



############## start of menu function #############
function menu () {

cat << END_OF_MENU

  S         Census
  L         Log Reporter
  C         Crash Reporter
  F         View full documentation in your browser
  Z         View quick start guide in your browser
  N         Change or set your Cix nickname and Vienna version
  T         View the last report generated in Textedit
  M         Send email to the maintainer of this program
  Q         Quit this program

END_OF_MENU
read -p "Please make your choice [SLCFZNTMQ] ? : " choice

    case "${choice}" in
	 [Ss] )  REPORT_TYPE=Census ; reporter ;;
	 [Ll] )  REPORT_TYPE=Log ; reporter ;;
	 [Cc] )  REPORT_TYPE=Crash ; reporter;;
	 [Ff] )  full_docs ;;
	 [Zz] )  quick_start ;;
	 [Nn] )  cix_nick ;;
         [Tt] )  view_in_textedit ;;
         [Mm] )  send_email ;;
	 [Qq] )  exit 0;;
     esac 

}  ######### end of menu function ###########

########### begin view_in_textedit function ###########
function view_in_textedit () {
if [ -f "${T}" ]
then
opin_in_textdit_todo
else
echo
echo You have not generated any reports yet
echo
fi
return 0

}
############ end of view_in_textedit function ###########



############# start of main script ###########
# all functions must precede this #

while true; do menu ;done


