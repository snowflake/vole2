# Makefile for the Vienna census

FILES=vlcr.sh readme.html manifest.uuid manual.html quick_start.html


all:

zip:	checkedin
	cp ../manifest.uuid .
	zip vlcr.zip ${FILES}

checkedin:
	[  `fossil changes | wc -l` -eq 0 ]
