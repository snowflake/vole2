# Makefile for the Vienna census

all:

zip:	checkedin
	cp ../manifest.uuid .
	zip census.zip vlcr.sh readme.html manifest.uuid

checkedin:
	[  `fossil changes | wc -l` -eq 0 ]
