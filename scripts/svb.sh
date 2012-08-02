#!/bin/sh

# script to mark messages as read before a date, or as unread after a date

set -e
scriptversion=1.2
database="${HOME}/Library/Vienna/database3.db"

# 0 - message unread, 1 = message read
read_flag=0

voleid="uk.co.opencommunity.vienna"
cixnick="$(defaults read ${voleid} Username)"


echo
echo 'Set Vole/Vinkix/Vienna message base back, version' "${scriptversion}"
echo 

if [ -z "${cixnick}" ]
then 
  echo 'Unable to determine your Cix nickname. Sorry, quiting now.'
  echo
  exit 1
fi

echo "Welcome Cix user ${cixnick}"
echo
read -p 'Please enter date in format YYYY-MM-DD : ' date
read -p 'Please enter time in format HH:MM      : ' time


echo
echo
echo 'Please enter R to mark messages read before date'
echo 'or U to mark messsages unread after date.'
echo
read -p 'Please choose R/U : ' ru
echo
case "${ru}" in
	[Rr] ) read_flag=1 ;;
	[Uu] ) read_flag=0 ;;
	*    ) echo 'Nothing to do, quiting'; exit 0 ;;
esac

if [ ${read_flag} -eq 0 ]
then
  compare='>='
else
  compare='<='
fi

echo 'Stage 1 of 6. Set read/unread.'

printf "BEGIN TRANSACTION; UPDATE messages SET read_flag = %s WHERE (date - strftime('%%s','%s %s')) %s 0 ; COMMIT;" \
    "${read_flag}" "${date}" "${time}" "${compare}"  | sqlite3 "${database}"

echo 'Stage 2 of 6. Set folders unread count and priority_unread_count to zero.'
echo 'UPDATE folders SET unread_count=0, priority_unread_count=0 ; ' | sqlite3 "${database}"

echo 'Stage 3 of 6. Recalculate folders unread count.'
cat << EOFBBB > /tmp/run.$$.sql
$(sqlite3 ${database}   'SELECT folder_id asc, count() FROM  messages WHERE read_flag = 0 GROUP BY folder_id  ;' | awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }' )
EOFBBB



echo 'Stage 4 of 6. Run the SQL script from stage 3 to update unread counts in folders.'
sqlite3 < /tmp/run.$$.sql "${database}"
[ -z "${SCRIPT_DEBUG}" ] && rm -f /tmp/run.$$.sql

echo 'Stage 5 of 6. Recalculate folders priority unread count.'

printf 'SELECT folder_id asc, count(*) FROM  messages WHERE priority_flag=1 AND read_flag = 0 GROUP BY folder_id  ;'  \
    |  sqlite3 "${database}" \
    |  awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET priority_unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }'  > /tmp/run2.$$.sql


echo 'Stage 6 of 6. Run the SQL script from stage 5 to update priority unread counts in folders.'
sqlite3 < /tmp/run2.$$.sql "${database}"
[ -z "${SCRIPT_DEBUG}" ] && rm -f /tmp/run2.$$.sql

echo 'Finished with no errors.'
echo



