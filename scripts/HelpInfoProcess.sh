#!/bin/sh

# Script to update the Info plist in the Help Book to the latest
# version and identifier.

# This script is now run from within Xcode
APPDIR=${BUILT_PRODUCTS_DIR}

echo "Configuration is ${CONFIGURATION}"
case ${CONFIGURATION} in
    ( *2 ) HelpBookName=VOLE2 ;;
    ( *   ) HelpBookName=VOLE1 ;;
esac
echo "HelpBookName is ${HelpBookName}"
AppName=Vole.app
HelpName=Vole.help
PLB=/usr/libexec/plistbuddy

AppInfo=${APPDIR}/${AppName}/Contents/Info.plist
HelpInfo=${APPDIR}/${AppName}/Contents/Resources/${HelpName}/Contents/Info.plist

if [ ! -f ${AppInfo} ]
then
    echo "No App Info.plist"
    exit 1
fi

if [ ! -f ${HelpInfo} ]
then
    echo "No Help Book Info.plist"
    exit 1
fi

set -e
# Get the version
Version=$( ${PLB}  -c "Print :CFBundleVersion" ${AppInfo} )
echo CFBundleVersion ${Version}
# Get the Bundle Identifier
Identifier=$( ${PLB} -c "Print :CFBundleIdentifier" ${AppInfo} )
echo CFBundleIdentifier ${Identifier}

HelpIdentifier=${Identifier}.help

# Set the version
${PLB} -x -c "Set :CFBundleVersion ${Version}" ${HelpInfo}
${PLB} -x -c "Set :CFBundleShortVersionString ${Version}" ${HelpInfo}

# Set the Help Identifier
${PLB} -x -c "Set :CFBundleIdentifier ${HelpIdentifier}" ${HelpInfo}

# Set the Help Book Name
if [ "${HelpBookName}" = "" ]
then
    echo "Need help book name to be set"
    exit 1
fi
${PLB} -x -c "Set :CFBundleName ${HelpBookName}" ${HelpInfo}
${PLB} -x -c "Set :HPDBookKBProduct ${HelpBookName}"   ${HelpInfo}

echo "HelpInfoProcess completed successfully"
exit 0

