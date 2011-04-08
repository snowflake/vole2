# Makefile for the Vienna census

FILES=vlcr.sh readme.html manifest.uuid manual.html quick_start.html \
	vlcr.sh.sig bugs.html


all:

clean:
	rm -f vlcr.zip vlcr.sh.sig

docs:
	sh vlcr.sh docgen

zip:	clean docs gpg checkedin
	cp ../manifest.uuid .
	zip vlcr.zip ${FILES}

gpg:
	gpg --no-armor --detach-sign vlcr.sh

checkedin:
	[  `fossil changes | wc -l` -eq 0 ]
