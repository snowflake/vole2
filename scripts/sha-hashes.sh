#!/bin/sh
set -e

# script to compute SHA-x hashes for the disk image.
# Environment variable VOLE_PGP_USER1 and VOLE_PGP_USER2 should
#  be set to the pgp user(s) hex key identities

if [ -n "${VOLE_PGP_USER1}" ]
then
USER1="-u ${VOLE_PGP_USER1}"
fi

if [ -n "${VOLE_PGP_USER2}" ]
then
USER2="-u ${VOLE_PGP_USER2}"
fi


rm -f temp-hash
for i in 1 224 256 384 512
do
/usr/bin/shasum --algorithm $i --binary $1 >> temp-hash
done

/opt/local/bin/gpg --clearsign  ${USER1} ${USER2}  --armor --digest-algo SHA512 \
	--comment "SHA hashes of ${1}" \
	--comment "Use /usr/bin/shasum to check the integrity of the file" \
		temp-hash

