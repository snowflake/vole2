all:

# This Makefile is run from the Vienna/Makefile with target validate-help.
# Must be run by Macports gmake, as Apple /usr/bin/make is too old for .ONESHELL
.ONESHELL:
.PHONY: validate
validate:
	export SGML_CATALOG_FILES=/opt/local/share/sgml/html/catalog
	export SP_BCTF=utf-8
	set -e
	cd "English.lproj/Vienna Help"
	pwd
	for i in *.html
	do
	echo $$i
	/opt/local/bin/onsgmls -s $$i
	tidy -q -utf8 1>/dev/null $$i
	done
	echo 'If you see this then there are no validation errors.'
	
