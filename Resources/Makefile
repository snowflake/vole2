all:   cp1252_to_vole.h

cp1252_to_vole.h: table.awk VoleCharacterSet.txt
	cat VoleCharacterSet.txt \
		| awk -f table.awk TABLENAME=cp1252_to_vole  > j1

