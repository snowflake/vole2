#!/bin/sh

echo "Build help index script"

# Generate the help Index for vole

LOCAL=English.lproj
HELP_BOOK_DIR=Vole.help
INDEX_NAME=Vole.helpindex
LPROJ_DIR="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources/${HELP_BOOK_DIR}/Contents/Resources/${LOCAL}/"

echo "Lproj dir: ${LPROJ_DIR}"


if [ ! -d "${LPROJ_DIR}" ]
   then
    echo "makevolehelpindex: no .lproj"
    exit 1	
    fi

/usr/bin/hiutil -C -f "${LPROJ_DIR}/${INDEX_NAME}" -s en -m 3 "${LPROJ_DIR}"

exit $?
