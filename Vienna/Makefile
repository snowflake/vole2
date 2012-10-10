# Makefile for Vole
# Copyright (C) 2011 David Evans

all: 
	@echo read the makefile

Development-release: NAME=dv
Development-release: COMPATIBILITY=Unknown
Development-release: STATUS=Experimental

tiger-release: NAME=vt
tiger-release: COMPATIBILITY=Tiger (10.4) and later, Universal.
tiger-release: STATUS=Usable but see Release Notes for a couple of bugs.

leopard-release: NAME=vl
leopard-release: COMPATIBILITY=Leopard (10.5) and later, Universal.
leopard-release: STATUS=Experimental, may crash, needs testing

snowleopard-release: NAME=vs
snowleopard-release: COMPATIBILITY=Snow Leopard (10.6) and later, Intel
snowleopard-release: STATUS=Experimental, may crash, needs testing

lion-release: NAME=vn
lion-release: COMPATIBILITY=Lion (10.7) and later, Intel
lion-release: STATUS=Not yet available

Development: SHORT=DV
tiger:	     SHORT=TG
leopard:     SHORT=LP
snowleopard: SHORT=SL
lion:	     SHORT=LN

# Development Development-go:	DEVELOPER_DIR?=/Developer
tiger tiger-release tiger-go:	DEVELOPER_DIR?=/Developer 
leopard leopard-release leopard-go: 	DEVELOPER_DIR?=/Developer
snowleopard snowleopard-release snowleopard-go:	DEVELOPER_DIR?=/Developer
lion lion-release lion-go: 			DEVELOPER_DIR?=/Developer

SHORTDATE=`date '+%Y%m%d'`

SOURCE_DIR=../../Vienna-build/$(subst -release,,$@)
SOURCE_FILES=Vole.app RELEASE.html BUILD.html INSTALL.html
BUILD_INFO=${SOURCE_DIR}/BUILD.html
VIENNA_APP=${SOURCE_DIR}/Vole.app/Contents/MacOS/Vole
VERSION=$(shell ${VIENNA_APP} -m)
PATH=${DEVELOPER_DIR}/usr/bin:/usr/local/bin:/usr/bin:/bin

tiger leopard snowleopard lion Development:
	echo $@
	rm -f XXXX-Tempfile.h
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project Vole.xcodeproj  -configuration $@ clean 
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project Vole.xcodeproj  -configuration $@ \
		BUILDID=${SHORT}-${SHORTDATE} 

# Run the version of Xcode appropiate to the target
tiger-go leopard-go snowleopard-go lion-go Development-go:
	open ${DEVELOPER_DIR}/Applications/Xcode.app

# Run the Vienna app from its build directory
tiger-run leopard-run snowleopard-run lion-run Development-run:
	open ../../Vienna-build/$(subst -run,,$@)/Vole.app



# where to put the saved releases
ARCHIVE_DIR=~/Vienna-archive

tiger-release leopard-release snowleopard-release lion-release \
			Development-release: 
	DEVELOPER_DIR=${DEVELOPER_DIR} \
		make $(subst -release,,$@)
	echo $@
	echo ${VIENNA_APP}
	[ -d ${SOURCE_DIR} ]
	echo '<html><head><title>Vole build info</title></head>' > ${BUILD_INFO}
	echo '<body><pre>' >> ${BUILD_INFO}
	echo 'This file contains build information for Vole ' \
		>> ${BUILD_INFO}
	echo "version ${VERSION}" >> ${BUILD_INFO}
	echo '==========================================================================' \
		>> ${BUILD_INFO}
	${VIENNA_APP} -d \
		>> ${BUILD_INFO}
	echo '</pre></body></html>' >> ${BUILD_INFO}
	cp ../NOTES/RELEASE.html ${SOURCE_DIR}
	cp ../NOTES/INSTALL.html ${SOURCE_DIR}
	rm -f template.dmg wc.dmg template.dmg.bz2
	make -f ../mk/make-dmg.mk SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION} clean
	make -f ../mk/make-dmg.mk SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION}
	/opt/local/bin/gpg --no-armor --detach-sign "${NAME}-${VERSION}.dmg"
	sh ../scripts/readme-gen.sh "${NAME}-${VERSION}" > README.html
	zip -0 --must-match ${NAME}-${VERSION}.zip README.html \
		${NAME}-${VERSION}.dmg ${NAME}-${VERSION}.dmg.sig
	sh ../scripts/buildcix.sh \
		"${VIENNA_APP}" \
		${NAME}-${VERSION}.zip \
		${NAME}-${VERSION}.cix \
		"Compatibility: ${COMPATIBILITY}" \
		"Status: ${STATUS}"
	sh ../scripts/yesno.sh "Do you want to archive this build y/n : "
	[ -d ${ARCHIVE_DIR} ]
	cp ${NAME}-${VERSION}.zip \
		${ARCHIVE_DIR}/${NAME}-${VERSION}-`${VIENNA_APP}  -b`.zip

releasenotes:
	[ -f ~/mac/sources-mine/vole/RELEASES ]
	cat ~/mac/sources-mine/vole/RELEASES | \
		awk -f ../scripts/makereleaseindex.awk | \
		fossil wiki commit RINOTES

