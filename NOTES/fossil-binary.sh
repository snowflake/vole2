#!/bin/sh

# Fossil needs to be told about binary files so it doesn't try to merge them
# I don't know that to do about Vienna Help idx in the Vienna Help directory

BINARIES=*.tiff,*.jpeg,*.jpg,*.gif,*.nib,*.xib,*.tar,rz,sz,sqlite2,\
sqlite3,*.icns,*.plist,*.a,*.o,*.lo,*.la,*.rtf,*.pbxproj,*.pch,\
*.xml,*.pbxuser,*.mode1,*.perspective,*.scriptTerminology,\
*.xcodeproj,*idx

fossil setting binary-glob ${BINARIES}
