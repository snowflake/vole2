# Makefile for the Vienna census

all:

zip:	checkedin
	cp ../manifest.uuid .
	zip census.zip census.sh readme.html manifest.uuid

checkedin:
	[  `fossil changes | wc -l` -ne 0 ]
