all:   cp1252_to_vole.h vole_to_cp1252.h

cp1252_to_vole.h: table.awk VoleCharacterSet.txt
	cat VoleCharacterSet.txt \
		| awk -f table.awk TABLENAME=cp1252_to_vole  > j1

vole_to_cp1252.h: table.awk Vole_to_CP1252.txt
	cat Vole_to_CP1252.txt \
		| awk -f table.awk TABLENAME=vole_to_cp1252 > j2

