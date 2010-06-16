#
# Script to build the Zmodem helper binaries

#This may be useful...

ZMDIR=zmodem

if [ x${ACTION} = xclean ]; then
	echo "cleaning"
	cd ${ZMDIR}
	make clean
	exit 0
fi

#Note. these are hand-built fat binaries
# sqlite2 is needed for the automatic 2->3 upgrade procedure
ditto sqlite2 rz sz ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}

exit 0
