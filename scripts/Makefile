SVBVERSION=$(shell sh svb.sh version)


all:
	echo Read the makefile


svb-zip:
	zip svb-${SVBVERSION}.zip svb.sh svb.txt

# describe the file for a posting in vienna/files
svb-cixfile:	svb-zip
	sh svb.sh cixfile > svb.cix

