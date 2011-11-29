#!/bin/sh

# Run this script after you have set up a new Repo.

# Fossil needs to be told about binary files so it doesn't try to merge them.
# I don't know what to do about Vienna Help idx in the Vienna Help directory.

BINARIES=*.tiff,*.jpeg,*.jpg,*.gif,*.nib,*.xib,*.tar,rz,sz,sqlite2,\
sqlite3,*.icns,*.plist,*.a,*.o,*.lo,*.la,*.rtf,*.pbxproj,*.pch,\
*.xml,*.pbxuser,*.mode1,*.perspective,*.perspectivev3,*.scriptTerminology,\
*.xcodeproj,*idx

IGNORE=*.mode1,*.pbxuser,*.perspective,*.perspectivev3

fossil setting binary-glob ${BINARIES}
fossil setting ignore-glob ${IGNORE}
