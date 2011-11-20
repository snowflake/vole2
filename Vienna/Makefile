

all: 
	@echo read the makefile

Development-release: NAME=dv
Development-release: COMPATIBILITY=Unknown
Development-release: STATUS=Experimental

tiger-release: NAME=vt
tiger-release: COMPATIBILITY=Tiger (10.4) and later, Universal
tiger-release: STATUS=Stable - no known bugs at this time

leopard-release: NAME=vl
leopard-release: COMPATIBILITY=Leopard (10.5) and later, Universal
leopard-release: STATUS=Experimental, may crash, needs testing

snowleopard-release: NAME=vs
snowleopard-release: COMPATIBILTY=Snow Leopard (10.6) and later, Intel
snowleopard-release: STATUS=Experimental, may crash, needs testing

lion-release: NAME=vn
lion-release: COMPATIBILITY=Lion (10.7) and later, Intel
lion-release: STATUS=Not yet available

Development: SHORT=DV
tiger:	     SHORT=TG
leopard:     SHORT=LP
snowleopard: SHORT=SL
lion:	     SHORT=LN

SHORTDATE=`date '+%Y%m%d'`

SOURCE_DIR=../../Vienna-build/$(subst -release,,$@)
SOURCE_FILES=Vienna.app RELEASE.html BUILD.html INSTALL.html
BUILD_INFO=${SOURCE_DIR}/BUILD.html
VIENNA_APP=${SOURCE_DIR}/Vienna.app/Contents/MacOS/Vienna
VERSION=$(shell ${VIENNA_APP} -m)
tiger leopard snowleopard lion Development:
	echo $@
	rm -f XXXX-Tempfile.h
	xcodebuild -project Vienna.xcodeproj  -configuration $@ clean	
	xcodebuild -project Vienna.xcodeproj  -configuration $@ \
		BUILDID=${SHORT}-${SHORTDATE}

# where to put the saved releases
ARCHIVE_DIR=~/Vienna-archive

tiger-release leopard-release snowleopard-release lion-release \
			Development-release: 
	make $(subst -release,,$@)
	echo $@
	echo ${VIENNA_APP}
	[ -d ${SOURCE_DIR} ]
	echo '<html><head><title>Vienna build info</title></head>' > ${BUILD_INFO}
	echo '<body><pre>' >> ${BUILD_INFO}
	echo 'This file contains build information for Vienna ' \
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
	gpg --no-armor --detach-sign "${NAME}-${VERSION}.dmg"
	sh ../scripts/readme-gen.sh "${NAME}-${VERSION}" > README.html
	zip -0 --must-match ${NAME}-${VERSION}.zip README.html \
		${NAME}-${VERSION}.dmg ${NAME}-${VERSION}.dmg.sig
	sh ../scripts/buildcix.sh \
 		"${VIENNA_APP}"  \
		${NAME}-${VERSION}.zip \
		${NAME}-${VERSION}.cix \
		"Compatibility: ${COMPATIBILITY}" \
		"Status: ${STATUS}"
	sh ../scripts/yesno.sh "Do you want to archive this build y/n : "
	[ -d ${ARCHIVE_DIR} ]
	cp ${NAME}-${VERSION}.zip \
		${ARCHIVE_DIR}/${NAME}-${VERSION}-`${VIENNA_APP}  -b`.zip

