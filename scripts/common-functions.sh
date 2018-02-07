# This file is for including into other scripts

function nolf(){
# delete linefeeds from stdin
   tr -d '\012'
}

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

# This will work if we have two .xcodeproj directories in the Vienna directory,
# unlike agvtool.
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${INFOPLIST_FILE}

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

function stripquotes(){
    sed 's/"//g'
}


