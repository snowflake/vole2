# Makefile for Vole
# Copyright (C) 2011 David Evans

all: 
ifdef VOLE_QUICK_BUILD
	${VOLE_QUICK_BUILD}
else
	@echo 'For make all, define VOLE_QUICK_BUILD in your environment'
	@echo 'to be an xcodebuild command string.'
	@echo 'Example for /bin/sh in your ~/.profile'
	@echo 'VOLE_QUICK_BUILD="xcodebuild -project Vole_xc5.xcodeproj -configuration elcapitan2 -sdk macosx10.11"'
	@echo 'export VOLE_QUICK_BUILD'
	exit 1
endif

clean:
ifdef VOLE_QUICK_BUILD
	${VOLE_QUICK_BUILD} clean
else
	@echo 'For make clean, define VOLE_QUICK_BUILD in your environment'
	@echo 'to be an xcodebuild command string.'
	@echo 'Example for /bin/sh in your ~/.profile'
	@echo 'VOLE_QUICK_BUILD="xcodebuild -project Vole_xc5.xcodeproj -configuration elcapitan2 -sdk macosx10.11"'
	@echo 'export VOLE_QUICK_BUILD'
	exit 1
endif

analyze:
ifdef VOLE_QUICK_BUILD
	${VOLE_QUICK_BUILD} -xcconfig xcconfig/XcodeWarnings.xcconfig
else
	@echo VOLE_QUICK_BUILD not defined
	exit 1
endif

#******************************** Warning ***********************************

# MOSXDT in this Makefile must be kept in step with VOLE_DEPLOYMENT_TARGET
# preprocessor macros in the Xcode Project for each configuration.

#****************************************************************************

APPNAME=Vole.app

DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT?=YES
DEBUG_INFORMATION_FORMAT?=dwarf-with-dsym

# set up appropiate developer dirs, can be changed in environment
DEVELOPER_DIR_XC3?= /Xcode3.2.6
DEVELOPER_DIR_XC5?= NOT_CURRENTLY_AVAILABLE
DEVELOPER_DIR_XC6?= /Applications/Xcode.app/Contents/Developer
DEVELOPER_DIR_XC6_BETA?=/Applications/Xcode_beta/Xcode.app/Contents/Developer
DEVELOPER_DIR_XC7_BETA?=/Applications/Xcode_beta/Xcode-beta.app/Contents/Developer
DEVELOPER_DIR_XC7?=/Applications/Xcode.app/Contents/Developer
DEVELOPER_DIR_XC8?=/Applications/Xcode.app/Contents/Developer

PROJECT_XC3=Vole_xc3.xcodeproj
PROJECT_XC5=Vole_xc5.xcodeproj
PROJECT_XC6=${PROJECT_XC5}
PROJECT_XC7=${PROJECT_XC5}
PROJECT_XC8=${PROJECT_XC5}

# Xcode.app locations
XC3_XCODE_APP=${DEVELOPER_DIR_XC3}/Applications/Xcode.app
XC5_XCODE_APP?=NOT_CURRENTLY_AVAILABLE
XC6_XCODE_APP?=/Applications/Xcode.app
XC6BETA_XCODE_APP?=/Applications/Xcode_beta/Xcode.app
XC7BETA_XCODE_APP?=/Applications/Xcode_beta/Xcode-beta.app
XC7_XCODE_APP?=/Applications/Xcode.app
XC8BETA_XCODE_APP?=/Applications/Xcode_beta/Xcode-beta.app

BUILDS:=	Development tiger leopard snowleopard lion mountainlion \
		mavericks yosemite elcapitan elcapitan2 sierra sierra2
RELEASES:= 	Development-release tiger-release leopard-release \
		snowleopard-release lion-release mountainlion-release \
		mavericks-release yosemite-release elcapitan-release \
		elcapitan2-release sierra-release sierra2-release

Development-release: NAME=dv
Development-release: COMPATIBILITY=Unknown
Development-release: STATUS=Experimental

tiger-release: NAME=vt
tiger-release: COMPATIBILITY=Tiger (10.4) and later, Universal.
tiger-release: STATUS=Recommended for everyone.
tiger-release tiger: MOSXDT=10.4
# archs must be given in the order ppc i386 x86_64
tiger-release tiger: ARCHS?=ppc i386
tiger-release tiger: DEVELOPER_DIR=${DEVELOPER_DIR_XC3}
tiger-release tiger: SDK_NAME=macosx10.4
tiger-release tiger tiger-go: PROJECT=${PROJECT_XC3}

leopard-release: NAME=vl
leopard-release: COMPATIBILITY=Leopard (10.5) and later, Universal.
leopard-release: STATUS=Experimental, may crash, needs testing
leopard-release leopard: MOSXDT=10.5
# archs must be given in the order ppc i386 x86_64
leopard-release leopard: ARCHS?=ppc i386 x86_64
leopard-release leopard: DEVELOPER_DIR=${DEVELOPER_DIR_XC3}
leopard-release leopard: SDK_NAME=macosx10.5
leopard-release leopard leopard-go: PROJECT=${PROJECT_XC3}

snowleopard-release: NAME=vs
snowleopard-release: COMPATIBILITY=Snow Leopard (10.6) and later, Intel
snowleopard-release: STATUS=Experimental, may crash, needs testing
snowleopard-release snowleopard: MOSXDT=10.5
# archs must be given in the order ppc i386 x86_64
snowleopard-release snowleopard: ARCHS?=ppc i386 x86_64
snowleopard-release snowleopard: DEVELOPER_DIR=${DEVELOPER_DIR_XC3}
snowleopard-release snowleopard: SDK_NAME=macosx10.6
snowleopard-release snowleopard snowleopard-go: PROJECT=${PROJECT_XC3}

mountainlion-release: 	            NAME=vm
mountainlion-release:               COMPATIBILITY=Lion and Later
mountainlion-release:               STATUS=Experimental
mountainlion-release mountainlion: MOSXDT=10.7
# archs must be given in the order ppc i386 x86_64
mountainlion-release mountainlion: ARCHS?=x86_64
mountainlion-release mountainlion: DEVELOPER_DIR=${DEVELOPER_DIR_XC5}
mountainlion-release mountainlion: SDK_NAME=macosx10.8
mountainlion-release mountainlion mountainlion-go: PROJECT=${PROJECT_XC5}

mavericks-release: NAME=vv
mavericks-release: COMPATIBILITY=Tiger and Later, Intel
mavericks-release: STATUS=Seems to be OK
mavericks-release mavericks: MOSXDT=10.7
# archs must be given in the order ppc i386 x86_64
mavericks-release mavericks: ARCHS?=x86_64
mavericks-release mavericks: DEVELOPER_DIR=${DEVELOPER_DIR_XC6}
mavericks-release mavericks: SDK_NAME=macosx10.9
mavericks-release mavericks mavericks-go: PROJECT=${PROJECT_XC6}

yosemite-release:          NAME=vy
yosemite-release:          COMPATIBILITY=
yosemite-release:          STATUS=experimental
yosemite-release yosemite: MOSXDT=10.7
# archs must be given in the order ppc i386 x86_64
yosemite-release yosemite: ARCHS?=x86_64
yosemite-release yosemite: DEVELOPER_DIR=${DEVELOPER_DIR_XC6}
yosemite-release yosemite: SDK_NAME=macosx10.10
yosemite-release yosemite yosemite-go: PROJECT=${PROJECT_XC6}

elcapitan-release:	NAME=ve
elcapitan-release:	COMPATIBILITY=
elcapitan-release:	STATUS=Alpha testing
elcapitan-release elcapitan: MOSXDT=10.7
elcapitan-release elcapitan: ARCHS?=x86_64
elcapitan-release elcapitan: DEVELOPER_DIR=${DEVELOPER_DIR_XC7}
elcapitan-release elcapitan: SDK_NAME=macosx10.11
elcapitan-release elcapitan elcapitan-go: PROJECT=${PROJECT_XC7}

elcapitan2-release:	NAME=v2e
elcapitan2-release:	COMPATIBILITY=
elcapitan2-release:	STATUS=Alpha testing
elcapitan2-release elcapitan2: MOSXDT=10.7
elcapitan2-release elcapitan2: ARCHS?=x86_64
elcapitan2-release elcapitan2: DEVELOPER_DIR=${DEVELOPER_DIR_XC7}
elcapitan2-release elcapitan2: SDK_NAME=macosx10.11
elcapitan2-release elcapitan2 elcapitan2-go: PROJECT=${PROJECT_XC7}

sierra-release:		NAME=vr
sierra-release:		COMPATIBILITY=
sierra-release:		STATUS=Alpha testing
sierra:			HelpBookName="Vole1"
sierra-release sierra: 	MOSXDT=10.7
sierra-release sierra:	ARCHS?=x86_64
sierra-release sierra: 	DEVELOPER_DIR=${DEVELOPER_DIR_XC8}
sierra-release sierra: 	SDK_NAME=macosx10.12
sierra-release sierra sierra-go: PROJECT=${PROJECT_XC7}

sierra2-release:		NAME=vr
sierra2-release:		COMPATIBILITY=
sierra2-release:		STATUS=Alpha testing
sierra2:			HelpBookName="Vole2"
sierra2-release sierra2: 	MOSXDT=10.7
sierra2-release sierra2:	ARCHS?=x86_64
sierra2-release sierra2: 	DEVELOPER_DIR=${DEVELOPER_DIR_XC8}
sierra2-release sierra2: 	SDK_NAME=macosx10.12
sierra2-release sierra2 sierra2-go: PROJECT=${PROJECT_XC7}


lion-release: NAME=vn
lion-release: COMPATIBILITY=Lion (10.7) and later, Intel
lion-release: STATUS=Not yet available


# OS X Releases
Development Development-release:  SN=0
tiger tiger-release:              SN=4
leopard leopard-release:          SN=5
snowleopard snowleopard-release:  SN=6
lion lion-release:	          SN=7
mountainlion mountainlion-release:SN=8
mavericks mavericks-release:      SN=9
yosemite yosemite-release:	  SN=10
elcapitan elcapitan-release:	  SN=11
elcapitan2 elcapitan2-release:	  SN=11
sierra sierra-release:		  SN=12
sierra2 sierra2-release:	  SN=12

BINARIES_DIR=${APPNAME}/Contents/MacOS
CSIGN=${BINARIES_DIR}/sqlite2 ${BINARIES_DIR}/rz ${BINARIES_DIR}/sz

# do this before finding the version
# INFOPLIST_FILE is also an xcode variable, and it may be defined
# in an xcconfig file as well
ifeq ($(findstring 2,${MAKECMDGOALS}),2)
# compiling Vole 2
INFOPLIST_FILE=Info-vole2.plist
else
INFOPLIST_FILE=Info.plist
endif
export INFOPLIST_FILE

${BUILDS}: SECONDS_SINCE_EPOCH=$(shell date -u +%s)
${BUILDS}: SHORTDATE=$(shell date -r ${SECONDS_SINCE_EPOCH} -u '+%Y%m.%d.%H%M%S')
${BUILDS}: VCSSTATUS:=$(shell /bin/sh ../scripts/version-script.sh vcs)
${BUILDS}: VCSDATE:=$(shell /bin/sh ../scripts/version-script.sh vcsdate)
SOURCE_DIR=../../Vienna-build/$(subst -release,,$@)
SOURCE_FILES=Vole.app RELEASE.html BUILD.html INSTALL.html
BUILD_INFO=${SOURCE_DIR}/BUILD.html
VIENNA_APP=${SOURCE_DIR}/Vole.app/Contents/MacOS/Vole
VERSION=$(shell INFOPLIST_FILE=${INFOPLIST_FILE} /bin/sh \
	../scripts/version-script.sh marketingversion)
PATH=${DEVELOPER_DIR}/usr/bin:/usr/local/bin:/usr/bin:/bin

.PHONY: check check2
check:
	make XCODE_XCCONFIG_FILE=xcconfig/check_everything.xcconfig \
		sierra
check2:
	make XCODE_XCCONFIG_FILE=xcconfig/XcodeWarnings-no-static-analyzer.xcconfig \
		sierra

.PHONY: ${BUILDS}
${BUILDS}: targetcheck
	@echo Target $@ building version ${VERSION}
	[ XX${DEVELOPER_DIR} != XX ]
	[ -d ${DEVELOPER_DIR} ] 
	rm -f XXXX-Tempfile.h
	/usr/bin/awk -f ../scripts/check_buildable.awk -v sdkname=${SDK_NAME}
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project ./${PROJECT}  -configuration $@ clean 
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project ./${PROJECT}  -configuration $@ \
		-sdk ${SDK_NAME} \
#		SECONDS_SINCE_EPOCH="${SECONDS_SINCE_EPOCH}" \
#		BUILDID="${SHORTDATE}" \
                VOLE_BUILD_STYLE=$@ \
		ARCHS="${ARCHS}"  \
		MACOSX_DEPLOYMENT_TARGET="${MOSXDT}" \
#		VCSSTATUS="${VCSSTATUS}" \
#		VCSDATE="${VCSDATE}" \
		DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT=${DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT} \
		DEBUG_INFORMATION_FORMAT=${DEBUG_INFORMATION_FORMAT}
# Postprocess the Help Book Info.plist
# (Now done within Xcode bUild Phases (DJE 6/2/2018))
#		../scripts/HelpInfoProcess.sh ${SOURCE_DIR} ${HelpBookName}

# Postprocess VoleInfo.plist
	cat VoleInfo.plist | awk -f ../scripts/postprocess_voleinfo.awk \
		vole=${VIENNA_APP} \
	        > ${SOURCE_DIR}/Vole.app/Contents/Resources/VoleInfo.plist
# add completion time to VoleInfo.plist (in the newly compiled app)
		sh ../scripts/completion_time.sh \
	           ${SOURCE_DIR}/Vole.app/Contents/Resources/VoleInfo.plist



# Run the version of Xcode appropriate to the target.
# This helps to preserve Xcode and Interface Builder integration
# especially on Xcode3.

# Xcode 3 projects:-
tiger-go leopard-go snowleopard-go:
	open -a ${XC3_XCODE_APP}  ${PROJECT}

# Xcode 5 projects:-
lion-go mountainlion-go :
	open -a ${XC5_XCODE_APP}  ${PROJECT}

# Xcode 6 projects:-
mavericks-go:
	open -a ${XC6_XCODE_APP}  ${PROJECT}

# Xcode 6 beta projects:-
yosemite-go:
	open -a ${XC6_XCODE_APP} ${PROJECT}

elcapitan-go elcapitan2-go:
	open -a ${XC7_XCODE_APP} ./${PROJECT}

sierra-go sierra2-go:
	open -a ${XC7_XCODE_APP} ./${PROJECT}

# Run the Vienna app from its build directory
tiger-run leopard-run snowleopard-run lion-run \
	mountainlion-run mavericks-run yosemite-run \
	elcapitan-run elcapitan2-run \
	sierra-run sierra2-run  Development-run:
	open ../../Vienna-build/$(subst -run,,$@)/Vole.app



# where to put the saved releases
ARCHIVE_DIR=~/Vienna-archive

.PHONY: ${RELEASES}
${RELEASES}: targetcheck
	rm -rf ${SOURCE_DIR}/*
	mkdir -p ${SOURCE_DIR}/app-temp
	DEVELOPER_DIR=${DEVELOPER_DIR} \
		make DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT=YES \
		   DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
		   $(subst -release,,$@)
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
	echo '=== Executable UUIDs ===' >> ${BUILD_INFO}
	dwarfdump --uuid ${VIENNA_APP} | awk '{ print $$1, $$2, $$3 }' >> ${BUILD_INFO}
	echo '</pre></body></html>' >> ${BUILD_INFO}
	cp ../NOTES/RELEASE.html ${SOURCE_DIR}
	cp ../NOTES/INSTALL.html ${SOURCE_DIR}
# archive the build
	sh ../scripts/archive-dsym.sh ${SOURCE_DIR}
# strip the release executable
	strip -S ${VIENNA_APP}
# codesign the app		
	# Codesign the helper commands rz sz sqlite2
	for i   in  ${CSIGN} ; do \
		echo ==== $$i ; \
		codesign -i uk.org.voleproject.vole-$$(basename $$i ) \
		   -f -s "Developer ID Application" ${SOURCE_DIR}/$$i ; \
		   done
	# Codesign Growl and Vole.app
	for i 	in  ${SOURCE_DIR}/${APPNAME}/Contents/Frameworks/Growl.framework/Versions/A \
		    ${SOURCE_DIR}/${APPNAME} ; do \
		echo ==== $$i ; \
		codesign -f -s "Developer ID Application" ${SOURCE_DIR}/$$i ; \
		done
	# sanity check to see if codesign worked
	codesign --verify --verbose=4 --deep ${SOURCE_DIR}/${APPNAME}
# create the package
ifdef DONTDEFINETHIS
	(cd ${SOURCE_DIR} && \
	   tar cf - Vole.app ) | tar xf - -C ${SOURCE_DIR}/app-temp
	pkgbuild --root $$(pwd)/${SOURCE_DIR}/app-temp  \
	   --component-plist pkg-component.plist \
	    --install-location /JUNK2 junk.pkg
endif
# build the disk image
	rm -f template.dmg wc.dmg template.dmg.bz2
	make -f ../mk/make-dmg.mk SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION} clean
	make -f ../mk/make-dmg.mk SOURCE_DIR=${SOURCE_DIR} \
		SOURCE_FILES="${SOURCE_FILES}" NAME="${NAME}" \
		VERSION=${VERSION}
	@echo Codesign the disk image - do not resign it
	codesign -s "Developer ID Application" "${NAME}-${VERSION}.dmg"
	@echo Sign the disk image with gpg
	/opt/local/bin/gpg2 -u ${VOLE_PGP_USER1} -u ${VOLE_PGP_USER2} \
		--no-armor --detach-sign "${NAME}-${VERSION}.dmg"
	@echo Compute the SHA hashes and sign the file
	sh ../scripts/sha-hashes.sh "${NAME}-${VERSION}.dmg"
	cp temp-hash.asc disk-image-hashes.asc
	sh ../scripts/readme-gen.sh "${NAME}-${VERSION}" > README.html
	zip -0 --must-match ${NAME}-${VERSION}.zip README.html \
		${NAME}-${VERSION}.dmg ${NAME}-${VERSION}.dmg.sig \
		disk-image-hashes.asc
	sh ../scripts/buildcix.sh \
		"${VIENNA_APP}" \
		${NAME}-${VERSION}.zip \
		${NAME}-${VERSION}.cix \
		"Compatibility: ${COMPATIBILITY}" \
		"Status: ${STATUS}" \
		"${MOSXDT}" \
		"${ARCHS}" \
		"${SDK_NAME}"
	sh ../scripts/yesno.sh "Do you want to archive this build y/n : "
	[ -d ${ARCHIVE_DIR} ]
	cp ${NAME}-${VERSION}.zip \
		${ARCHIVE_DIR}/${NAME}-${VERSION}-`${VIENNA_APP}  -b`.zip

.PHONY: releasenotes
releasenotes:
	[ -f ~/mac/sources-mine/vole/RELEASES ]
	cat ~/mac/sources-mine/vole/RELEASES | \
		awk -f ../scripts/makereleaseindex.awk | \
		fossil wiki commit RINOTES

# validate-help requires Macports: gmake opensp html
.PHONY: validate-help
validate-help:
	/opt/local/bin/gmake -f ../mk/validate-html.mk validate

.PHONY: export-git
export-git:	# export fossil repo to git
	make -C ../mk -f export-to-git.mk  all push


.PHONY: appledoc
appledoc:
	cd ../scripts && sh appledoc.sh

.PHONY: targetcheck
targetcheck:
# Stop users specifying more than one target for build and release.
# This is because we scan the MAKECMDGOALS variable looking
# for the number 2, which determines if this is a vole2 build.
	@if [ `echo ${MAKECMDGOALS} | wc -w`  -gt 1 ] ; \
		then \
		echo 'Specifying two or more targets will lead to grief' ;\
		exit 1; fi

##############################################################################
.PHONY: generate-character-set-tables

CHARSET_GEN:= ~/Vienna-source/unicode-projects/table-generators

generate_character_set_tables:
# This target generates the character set lookup tables
	make -C ${CHARSET_GEN} cp1252sanitise > sanitise_string_private.h
	make -C ${CHARSET_GEN} cp1252lookup   > cp1252lookup.h
	make -C ${CHARSET_GEN} cp1252ucs4     > cp1252_to_ucs4.h
	make -C ${CHARSET_GEN} cp1252tovole   > cp1252_to_vole.h
	make -C ${CHARSET_GEN} voletocp1252   > vole_to_cp1252.h
