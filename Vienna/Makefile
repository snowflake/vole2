

all: 
	@echo read the makefile

tiger-release: NAME=vt
tiger-release: COMPATIBILITY=Tiger and later, Universal
leopard-release: NAME=vl
leopard-release: COMPATIBILITY=Leopard and later, Universal

SOURCE_DIR=../../Vienna-build/$(subst -release,,$@)
SOURCE_FILES=Vienna.app RELEASE.html BUILD.html
BUILD_INFO=${SOURCE_DIR}/BUILD.html
VERSION=`agvtool mvers -terse1`

tiger leopard:
	echo $@
#	xcodebuild -configuration $@ clean	
#	xcodebuild -configuration $@


tiger-release leopard-release: 
	make $(subst -release,,$@)
	echo $@
	echo '<html><head><title>Vienna build info</title></head>' > ${BUILD_INFO}
	echo '<body><pre>' >> ${BUILD_INFO}
	echo 'This file contains build information for Vienna ' \
		>> ${BUILD_INFO}
	echo "version ${VERSION}" >> ${BUILD_INFO}
	echo '==========================================================================' \
		>> ${BUILD_INFO}
	$(SOURCE_DIR)/Vienna.app/Contents/MacOS/Vienna -d \
		>> ${BUILD_INFO}
	echo '</pre></body></html>' >> ${BUILD_INFO}
	[ -d ${SOURCE_DIR} ]
	cp ../NOTES/RELEASE.html ${SOURCE_DIR}
	make -f make-dmg SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION} clean
	make -f make-dmg SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION}
	gpg --no-armor --detach-sign "${NAME}-${VERSION}.dmg"
	zip -0 --must-match ${NAME}-${VERSION}.zip README.html \
		${NAME}-${VERSION}.dmg ${NAME}-${VERSION}.dmg.sig
	sh buildcix.sh \
 		$(SOURCE_DIR)/Vienna.app/Contents/MacOS/Vienna  \
		${NAME}-${VERSION}.zip \
		${NAME}-${VERSION}.cix \
		"Compatibility: ${COMPATIBILITY}"
	
