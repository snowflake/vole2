#!/usr/bin/awk

# Generate a message for the files topic
BEGIN { FS="|" }

{ if(length() > 0 && $1 == "c" ) printf("cixfile:vienna/files:%s %s\n\n", $2, $3 );}
 
