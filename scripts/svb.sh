cat << EOFAAA | sqlite3 database3.db
BEGIN TRANSACTION; 
UPDATE folders SET unread_count=0 ;
update messages set read_flag = 1 where (strftime('%s','2012-07-01') - date) >0;
COMMIT;
EOFAAA
echo stage 1 done retcode $?
cat << EOFBBB > run.sql
$(sqlite3 database3.db   'SELECT folder_id asc, count(*) FROM  messages WHERE read_flag = 0 GROUP BY folder_id  ;' | awk 'BEGIN {FS="|" } { printf("UPDATE folders  SET unread_count=%s WHERE folder_id=%s ;\n",$2,$1); }' )
EOFBBB



