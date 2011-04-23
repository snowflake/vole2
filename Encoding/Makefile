all:

release: clean
	xcodebuild -sdk macosx10.4 -configuration Debug \
	ARCHS='i386 ppc' ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET=10.4 \
	GCC_VERSION=4.0

clean:
	xcodebuild -configuration Debug clean
	xcodebuild -configuration Release clean

