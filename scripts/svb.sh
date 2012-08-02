#!/bin/sh

# script to mark messages as read before a date, or as unread after a date

set -e
scriptversion=1.1
database="${HOME}/Library/Vienna/database3.db"

# 0 - message unread, 1 = message read
read_flag=0


echo 'Set Vole/Vinkix/Vienna message base back, version' "${scriptversion}"
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

echo 'Stage 1 of 4. Set read/unread.'

printf "BEGIN TRANSACTION; UPDATE messages SET read_flag = %s WHERE (date - strftime('%%s','%s %s')) %s 0 ; COMMIT;" \
    "${read_flag}" "${date}" "${time}" "${compare}"  | sqlite3 "${database}"

echo 'Stage 2 of 4. Set folders unread count to zero.'
echo 'UPDATE folders SET unread_count=0 ; ' | sqlite3 "${database}"

echo 'Stage 3 of 4. Recalculate folders unread count.'
cat << EOFBBB > /tmp/run.$$.sql
$(sqlite3 ${database}   'SELECT folder_id asc, count(*) FROM  messages WHERE read_flag = 0 GROUP BY folder_id  ;' | awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }' )
EOFBBB

echo 'Stage 4 of 4. Run the SQL script from stage 3 to update unread counts in folders.'
sqlite3 < /tmp/run.$$.sql "${database}"
rm -f /tmp/run.$$.sql
echo 'Finished with no errors.'
echo



