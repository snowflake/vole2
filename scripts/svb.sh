#!/bin/sh

# script to mark messages as read before a date, or as unread after a date

set -e
scriptversion=1.0
database="${HOME}/Library/Vienna/database3.db

# 0 - message unread, 1 = message read
read_flag=0



read -p 'Please enter date in format YYYY-MM-DD : ' date
read -p 'Please enter time in format HH:MM : ' time
echo $date
echo $time

if [ ${read_flag} -eq 0 ]
then
  compare='<='
else
  compare='>='
fi

echo 'Stage 1 of 4. Set read/unread.
'
printf "update messages set read_flag = %s where (strftime('%%s','%s %s') - date) %s 0 ;" ${read_flag} ${date} ${time} ${compare} 
#    | sqlite3 ${database}

exit
cat << EOFAAA | sqlite3 database3.db
BEGIN TRANSACTION; 
UPDATE folders SET unread_count=0 ;

COMMIT;
EOFAAA
echo stage 1 done retcode $?
cat << EOFBBB > /tmp/run.$$.sql
$(sqlite3 database3.db   'SELECT folder_id asc, count(*) FROM  messages WHERE read_flag = 0 GROUP BY folder_id  ;' | awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }' )
EOFBBB




