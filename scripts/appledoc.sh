#!/bin/sh
#appledoc documentation generator for Xcode docsets script.
# 2015-June-19
# Start constants
company="Vole";
companyID="com.vole";
companyURL="http://vole.com";
target="macosx";
outputPath="~/help/vole";
PROJECT_NAME="Vole";
PROJECT_DIR="../Vienna";
# End constants
/usr/local/bin/appledoc \
--ignore Growl.framework \
--keep-undocumented-objects \
--keep-undocumented-members \
--project-name "${PROJECT_NAME}" \
--project-company "${company}" \
--company-id "${companyID}" \
--docset-atom-filename "${company}.atom" \
--docset-feed-url "${companyURL}/${company}/%DOCSETATOMFILENAME" \
--docset-package-url "${companyURL}/${company}/%DOCSETPACKAGEFILENAME" \
--docset-fallback-url "${companyURL}/${company}" \
--output "${outputPath}" \
--publish-docset \
--docset-platform-family "${target}" \
--logformat xcode \
--keep-intermediate-files \
--no-repeat-first-par \
--no-warn-invalid-crossref \
--exit-threshold 2 \
"${PROJECT_DIR}"
