# Makefile for Vole
# Copyright (C) 2011 David Evans

all: 
	@echo read the makefile

#******************************** Warning ***********************************

# MOSXDT in this Makefile must be kept in step with VOLE_DEPLOYMENT_TARGET
# preprocessor macros in the Xcode Project for each configuration.

#****************************************************************************



# set up appropiate developer dirs, can be changed in environment
DEVELOPER_DIR_XC3?= /Xcode3.2.6
DEVELOPER_DIR_XC5?= /Applications/Xcode.app/Contents/Developer
PROJECT_XC3=Vole_xc3.xcodeproj
PROJECT_XC5=Vole_xc5.xcodeproj

# Xcode.app locations
XC3_XCODE_APP=${DEVELOPER_DIR_XC3}/Applications/Xcode.app
XC5_XCODE_APP?=/Applications/Xcode.app

BUILDS:=	Development tiger leopard snowleopard lion mountainlion \
		mavericks
RELEASES:= 	Development-release tiger-release leopard-release \
		snowleopard-release lion-release mountainlion-release \
		mavericks-release

Development-release: NAME=dv
Development-release: COMPATIBILITY=Unknown
Development-release: STATUS=Experimental

tiger-release: NAME=vt
tiger-release: COMPATIBILITY=Tiger (10.4) and later, Universal.
tiger-release: STATUS=Recommended for everyone.
tiger-release tiger: MOSXDT=10.4
# archs must be given in the order ppc i386 x86_64
tiger-release tiger: ARCHS=ppc i386
tiger-release tiger: DEVELOPER_DIR=${DEVELOPER_DIR_XC3}
tiger-release tiger: SDK_NAME=macosx10.4
tiger-release tiger tiger-go: PROJECT=${PROJECT_XC3}

leopard-release: NAME=vl
leopard-release: COMPATIBILITY=Leopard (10.5) and later, Universal.
leopard-release: STATUS=Experimental, may crash, needs testing
leopard-release leopard: MOSXDT=10.5
# archs must be given in the order ppc i386 x86_64
leopard-release leopard: ARCHS=ppc i386 x86_64
leopard-release leopard: DEVELOPER_DIR=${DEVELOPER_DIR_XC3}
leopard-release leopard: SDK_NAME=macosx10.5
leopard-release leopard leopard-go: PROJECT=${PROJECT_XC3}

snowleopard-release: NAME=vs
snowleopard-release: COMPATIBILITY=Snow Leopard (10.6) and later, Intel
snowleopard-release: STATUS=Experimental, may crash, needs testing
snowleopard-release snowleopard: MOSXDT=10.5
# archs must be given in the order ppc i386 x86_64
snowleopard-release snowleopard: ARCHS=ppc i386 x86_64
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
mavericks-release: STATUS=Experimental, needs testing
mavericks-release mavericks: MOSXDT=10.7
# archs must be given in the order ppc i386 x86_64
mavericks-release mavericks: ARCHS?=i386 x86_64
mavericks-release mavericks: DEVELOPER_DIR=${DEVELOPER_DIR_XC5}
mavericks-release mavericks: SDK_NAME=macosx10.9
mavericks-release mavericks mavericks-go: PROJECT=${PROJECT_XC5}

lion-release: NAME=vn
lion-release: COMPATIBILITY=Lion (10.7) and later, Intel
lion-release: STATUS=Not yet available



#Development: SHORT=DV 
Development Development-release:  SN=0
#tiger:	     SHORT=TG 
tiger tiger-release:              SN=4
#leopard:     SHORT=LP 
leopard leopard-release:          SN=5
#snowleopard: SHORT=SL
snowleopard snowleopard-release:  SN=6
#lion:	     SHORT=LN 
lion lion-release:	          SN=7
#mountainlion:SHORT=ML
mountainlion mountainlion-release:SN=8
#mavericks:   SHORT=MV
mavericks mavericks-release:      SN=9

# Development Development-go:	DEVELOPER_DIR?=/Developer
# tiger tiger-release tiger-go:	DEVELOPER_DIR?=/Developer 
# leopard leopard-release leopard-go: 	DEVELOPER_DIR?=/Developer
# snowleopard snowleopard-release snowleopard-go:	DEVELOPER_DIR?=/Developer
# lion lion-release lion-go: 			DEVELOPER_DIR?=/Developer

${BUILDS}: SHORTDATE:=$(shell date '+%Y%m%d.%H%M%S')

SOURCE_DIR=../../Vienna-build/$(subst -release,,$@)
SOURCE_FILES=Vole.app RELEASE.html BUILD.html INSTALL.html
BUILD_INFO=${SOURCE_DIR}/BUILD.html
VIENNA_APP=${SOURCE_DIR}/Vole.app/Contents/MacOS/Vole
VERSION=$(shell sh ../scripts/getversion.sh )
PATH=${DEVELOPER_DIR}/usr/bin:/usr/local/bin:/usr/bin:/bin

${BUILDS}:
	echo $@
	[ XX${DEVELOPER_DIR} != XX ]
	[ -d ${DEVELOPER_DIR} ] 
	rm -f XXXX-Tempfile.h
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project ${PROJECT}  -configuration $@ clean 
	DEVELOPER_DIR=${DEVELOPER_DIR} \
	xcodebuild -project ${PROJECT}  -configuration $@ \
		-sdk ${SDK_NAME} \
		BUILDID="${SHORTDATE}.${SN}" \
		ARCHS="${ARCHS}"  \
		MACOSX_DEPLOYMENT_TARGET="${MOSXDT}"

# Run the version of Xcode appropriate to the target.
# This helps to preserve Xcode and Interface Builder integration
# especially on Xcode3.
# Xcode 3 projects:-
tiger-go leopard-go snowleopard-go:
	open -a ${XC3_XCODE_APP}  ${PROJECT}
# Xcode 5 projects:-
lion-go mountainlion-go mavericks-go:
	open -a ${XC5_XCODE_APP}  ${PROJECT}


# Run the Vienna app from its build directory
tiger-run leopard-run snowleopard-run lion-run \
	mountainlion-run mavericks-run Development-run:
	open ../../Vienna-build/$(subst -run,,$@)/Vole.app



# where to put the saved releases
ARCHIVE_DIR=~/Vienna-archive

${RELEASES}:
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
	echo '=== Executable UUIDs ===' >> ${BUILD_INFO}
	dwarfdump --uuid ${VIENNA_APP} | awk '{ print $$1, $$2, $$3 }' >> ${BUILD_INFO}
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

