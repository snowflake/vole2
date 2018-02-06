#!/bin/sh

# Script to update the Info plist in the Help Book to the latest
# version and identifier.
# Argument 1  is the location of the built App.

APPDIR=${1}

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

