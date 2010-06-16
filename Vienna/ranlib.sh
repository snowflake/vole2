#!
set -e 

lipo -extract ppc libsqlite_fat.a -output ppc.a
lipo -extract i386 libsqlite_fat.a -output i386.a

ranlib ppc.a
ranlib i386.a

lipo -create ppc.a i386.a -output libsqlite_fat.a
