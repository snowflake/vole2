#!/bin/sh

# Script to update Info.plist with long version number and Version
# Control info.

set -e

PLB=/usr/libexec/PlistBuddy
VINFO=VoleInfo.plist

# location of Info.plist in the build products
INFO="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}" 

LONG_VERSION=$( ${PLB} -c "Print :BuildID" "${VINFO}" )
${PLB} -x -c "Set :CFBundleVersion ${LONG_VERSION}" "${INFO}"

VCSSTATUS=$(../scripts/version-script.sh vcs)
VCSDATE=$(../scripts/version-script.sh vcsdate)

${PLB} -x -c "Set :VoleVCSStatus ${VCSSTATUS}" "${INFO}"
${PLB} -x -c "Set :VoleVCSDate ${VCSDATE}"     "${INFO}"
