#!/bin/sh

# This script is run by Xcode during the build phase to generate information about
# the build in C header file format.  When run it produces a file which is included by main.m.
# Copy and paste this file into into Xcodes script window, or alternatively
# source this file from a small script in Xcode which does not need to be 
# changed much.

# If this script is called with $1 set to vcs, it displays version control
# status like this: Fossil(1) abcdefabcdef123456798888888888
#                          ^ count of unchecked files
#
# If this script is called with $1 set to vcsdate, it displays
# the version control checkin date.

# for finding Fossil
PATH=$SYSTEM_DEVELOPER_BIN_DIR:$PATH:/usr/local/bin

OF=XXXX-Tempfile.h
build_uuid=$(uuidgen | tr -d '\012')

function count_unchecked_files(){
  if fossil changes 2>/dev/null 1>/dev/null
     then
        fossil changes | wc -l
     elif git status -s -uno 2>/dev/null 1>/dev/null
     then
        git status -s -uno | wc -l
     else
        echo 99999
     fi
}

function version_control_type {
  if fossil status 2>/dev/null 1>/dev/null
  then
	echo Fossil
  elif git status -s  -uno 2>/dev/null 1>/dev/null
  then
	echo Git
  else
	echo Unknown
  fi 
}

function version_control_status(){
  if fossil status 2>/dev/null 1>/dev/null
  then
	echo '(Fossil)'
	(cd .. && fossil status)
  elif git status -s  -uno 2>/dev/null 1>/dev/null
  then
        echo '(Git)'
        echo 'Local root:' $(cd .. && pwd)
        git log -1
        (cd .. && git status -s -uno)
  else
        echo '(None)'
        echo 'Local root:' $(cd .. && pwd)
        echo 'No version control status available.'
  fi
}

function printlines(){
        # substitute \" for " in strings
        # previous version used sed
	cat | awk '{gsub(/"/,"\\\"");printf("\"%s\\n\"\n",$0);}'
}

function marketing_version(){
# Older versions of agvtool within Xcode have a different format 
# for the -terse option, and don't support the -terse1 option at all.
# Use the lowest common denominator and process with an awk script.


#agvtool mvers  | tail -1 | tr '"' '%' |\
#     awk 'BEGIN { FS="%"} { printf("%s",$2)}' 
# don't use agvtool, use PlistBuddy instead.
# This will work if we have two .xcodeproj directories in the Vienna directory
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist
}

function checkin(){
  if fossil changes 2>/dev/null 1>/dev/null
  then
    # within a Fossil checkout
cat <<EOF_FOSSIL_CHECKOUT
"Check-in: (Fossil) $(fossil status | awk '/^checkout:/ { print $2; exit}')\n"
"Check-in Date: $(fossil status | awk '/^checkout:/ { print $3,$4,$5; exit}')\n"
EOF_FOSSIL_CHECKOUT
  elif git status -s -uno 2>/dev/null 1>/dev/null
  then
    # within a Git checkout
cat <<EOF_GIT_CHECKOUT
"Check-in: (Git) $(git log -1 | awk '/^commit / {print $2;exit}')\n"
"Check-in Date: $(git log -1 | awk '/^Date: / {print $2,$3,$4,$5,$6,$7;exit}')\n"
EOF_GIT_CHECKOUT
  else
    # not within a checkout
    printf '"Check-in: (unknown)\\n"\n'
    printf '"Check-in Date: (unknown)\\n"\n'
  fi
}
function version_control_date(){
  if fossil changes 2>/dev/null 1>/dev/null
  then
    # within a Fossil checkout
    fossil status | awk '/^checkout:/ { printf "%s %s %s",$3,$4,$5 ; exit}'
  elif git status -s -uno 2>/dev/null 1>/dev/null
  then
    # within a Git checkout
  git log -1 | awk '/^Date: / {printf "%s %s %s %s %s %s", $2,$3,$4,$5,$6,$7;exit}'
  else
    # not within a checkout
    printf '(unknown - not within a VCS)'
  fi
}
function uuid_checkin(){
  # returns the checkin uuid
  if fossil changes 2>/dev/null 1>/dev/null
  then
     # within a Fossil checkout
     fossil status | awk '/^checkout:/ { print $2; exit}'
  elif git status -s -uno 2>/dev/null 1>/dev/null
  then
     # within a Git checkout
     git log -1 | awk '/^commit / {print $2;exit}'
  else
    # not within a checkout
    printf 'Unknown'
  fi
}

function changed_files(){
if fossil changes 2>/dev/null 1>/dev/null
then
  # within a fossil checkout
  echo '[Uncommitted files (Fossil)]' | printlines
  (cd .. && fossil changes) | printlines
elif git status -s -uno 2>/dev/null 1>/dev/null
then
   # within a git checkout
   echo '[Uncommitted files (Git)]' | printlines
   (cd .. && git status -s -uno ) | printlines
else
   # not within a checkout
   echo '[Version control status]' | printlines
   echo '*** Not within any version control check-in. ***' | printlines
fi
}
############# end of functions section #############

if [ x${1} = xvcs ]
then
  printf '%s(%s) %s' $(version_control_type) $(count_unchecked_files) $(uuid_checkin)  
exit 0
fi

if [ x${1} = xvcsdate ]
then
  version_control_date
  exit 0
fi

echo  Fossil checked-in files checking script

uuid=$(uuid_checkin)
rm -f "${OF}"
# Removing this file does not seem to force Xcode to recompile main.m.
# Sometimes it does, sometimes it does not. The safest thing is to do 
# an xcodebuild clean first.

#  see if agvtool produces an error - obsolete now
# agvtool mvers
# if [ $? -ne 0 ]
# then 
#	echo 'agvtool failed - You probably have multiple projects'
#	exit 1
# fi

cat >${OF} <<EOF_SCRIPT_HEADER
// *** This file is automatically generated - do not edit. ***
// *** Do not check this file into Fossil. ***
// This header file generated at $(date)
EOF_SCRIPT_HEADER
echo 'char buildinfo_1[]=' >>${OF}

unchecked_files=$(count_unchecked_files)  

if [ $unchecked_files -ne 0 ]
	then
	printf '"Warning: unchecked files = %d\\n"\n' $unchecked_files >> ${OF}
	printf '"==== Checkout does not reflect build files ====\\n"\n' >>${OF}
	fi
printf '"\\n"\n' >>${OF}
printf '"Version: %s\\n"\n'  $(marketing_version) >> ${OF} 
printf '"\\n"\n' >>${OF}

printf '"Build machine hostname: %s\\n"\n' `hostname -f` >> ${OF}
printf '"Built by username: %s\\n"\n' `whoami` >> ${OF}
printf '"Build UUID: %s\\n"\n' "${build_uuid}" >> ${OF}
printf '"Build ID: %s\\n"\n' "${BUILDID}" >> ${OF}
builddate=`date -u`
printf '"Built on: %s\\n\\n"\n' "$builddate"  >> ${OF}
printf '"=== Version control status ===\\n"\n' >>${OF}
version_control_status  | printlines >> ${OF}
if [ $unchecked_files -ne 0 ]	
then
printf '"Warning: %d unchecked files (this is bad).\\n"\n' $unchecked_files >>${OF}
printf '"   It means that the checkout does not reflect the state of the files used\\n"\n' >> ${OF}
printf '"   for this build.\\n"\n' >> ${OF}
fi		
printf '"\\n"\n' >>${OF}
printf '"Archs: %s\\n"\n' "${ARCHS}" >>${OF} 
printf '"Build Style: %s\\n"\n' "${BUILD_STYLE}" >>${OF}
printf '"Build Variants: %s\\n"\n' "${BUILD_VARIANTS}" >>${OF}
printf '"Configuration: %s\\n"\n'  "${CONFIGURATION}"  >>${OF}
printf '"Project File Path: %s\\n"\n' "${PROJECT_FILE_PATH}" >>${OF}
printf '"Garbage collection: %s\\n"\n' "${GCC_ENABLE_OBJC_GC}" >>${OF}
printf '"Debugging Symbols:%s\\n"\n' "${DEBUGGING_SYMBOLS}" >>${OF}
printf '"Debug Information Format: %s\\n"\n' "${DEBUG_INFORMATION_FORMAT}" >>${OF}
printf '"GCC Version: %s\\n"\n' "${GCC_VERSION}" >>${OF}

# the next two lines are tricky
printf '#ifdef __VERSION__\n"GCC: " __VERSION__ "\\n" \n#endif\n' >>${OF}
printf '#ifdef __clang_version__\n"Clang: " __clang_version__ "\\n" \n#endif\n' >>${OF}

printf '"GCC/Clang optimization level: %s\\n"\n' "${GCC_OPTIMIZATION_LEVEL}" >>${OF}
printf '"MacOSX Deployment Target: %s\\n"\n' "${MACOSX_DEPLOYMENT_TARGET}" >>${OF}
printf ';\n' >> ${OF}

printf 'char buildinfo_2[]=\n' >> ${OF}
printf '"Product Name: %s\\n"\n' "${PRODUCT_NAME}" >>${OF}
printf '"SDK Root: %s\\n"\n' "${SDKROOT}" >>${OF}
printf '"SDK Name: %s\\n"\n' "${SDK_NAME}" >>${OF}
printf '"SDK Product Build Version: %s\\n"\n' "${SDK_PRODUCT_BUILD_VERSION}" >> ${OF}
echo   '=== Xcode ===' | printlines >>${OF}
xcodebuild -version | printlines >> ${OF}
echo '=== build machine sw_vers ===' | printlines >> ${OF}
sw_vers | printlines >> ${OF}
echo '=== SQLite ===' | printlines >> ${OF}
echo \; >>${OF}
printf 'int unchecked_files = %d;\n' $unchecked_files >>${OF}
printf 'char source_code_fossil_uuid[]="%s";\n' $uuid >>${OF}
printf 'char build_uuid[]="%s";\n' "${build_uuid}" >> ${OF}
printf 'char marketing_version[]="%s";\n' "$(marketing_version)" >> ${OF}
printf 'char build_short_id[]="%s";\n' "${BUILDID}" >> ${OF}

cat >> ${OF} << BUILD_INFO_EOF
/* vole_build_info is for appending Vole information to
 * messages posted in the vienna conference.
 * This is the Vole Status Report (Vole->Develop->Status Report)
 */
char vole_build_info[]=
"[${PRODUCT_NAME} Build]\n"
"Version: $(marketing_version)\n"
"Build Date: ${builddate}\n"
"Build: ${BUILDID}\n"
"Build UUID: ${build_uuid}\n"
"Built by user: ${USER}\n"
"Src Location: $(cd .. && pwd)\n"
"SDK: ${SDK_NAME} ${SDK_PRODUCT_BUILD_VERSION}\n"
"Deployment Target: ${MACOSX_DEPLOYMENT_TARGET}\n"
"Architectures: ${ARCHS}\n"
$(checkin)
"\n";

// changed, added or deleted files.
char vole_vcs_changes[] =
BUILD_INFO_EOF

if [ $unchecked_files -ne 0 ]
   then 
   cat >> ${OF} <<EOF_UCF
$(changed_files)
"\n";
EOF_UCF
   else
   printf '""; // No Uncommited files.\n' >>${OF}
fi




if [ $unchecked_files -ne 0 ]
	then 
		echo ERROR files not checked into Fossil or Git.
	fi
echo 'version-script.sh completed'
exit 0
