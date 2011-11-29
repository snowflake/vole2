all:

build: clean
	xcodebuild -sdk macosx10.4 -configuration Debug \
	ARCHS='i386 ppc' ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET=10.4 \
	GCC_VERSION=4.0
release:	build
	make -f ../mk/make-dmg.mk NAME=encode VERSION=1.0 \
		SOURCE_DIR=build/Debug SOURCE_FILES=Encoding.app
	


clean:
	xcodebuild -configuration Debug clean
	xcodebuild -configuration Release clean

