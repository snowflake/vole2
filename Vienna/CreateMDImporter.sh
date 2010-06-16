#
# Script to build the Spotlight Metadata Importer.
# Shamelessly stolen from "fire" http://fire.sourceforge.net/
#

ver=`uname -r`
#check to make sure we are running tiger, otherwise this will not build
if [[ "$ver" < "8.0" ]]; then
    exit 0
fi

if [ x${ACTION} = xclean ]; then
	echo "cleaning"
	cd ${MDDirectory}
	xcodebuild -project Vienna.xcodeproj -buildstyle ${BUILD_STYLE} clean
	exit 0
fi

cd ${MDDirectory}
xcodebuild -project Vienna.xcodeproj -buildstyle ${BUILD_STYLE}

if(test -d build/${MDTarget}.mdimporter) then
    file=build/${MDTarget}.mdimporter
else
    file=build/${BUILD_STYLE}/${MDTarget}.mdimporter
fi

ditto -rsrc $file ${BUILT_PRODUCTS_DIR}/${MDTargetApp}/Contents/Library/Spotlight/${MDTarget}.mdimporter

exit 0
