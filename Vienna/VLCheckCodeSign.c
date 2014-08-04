/* Check code signing for the App */

#include <Security/Security.h>
#include <stdio.h>
#include <syslog.h>
#include "VLCheckCodeSign.h"

void checkCodeSigning(){

SecCodeRef 	code;
SecStaticCodeRef staticcode;
OSStatus rc; 		/* return code */

rc= SecCodeCopySelf(kSecCSDefaultFlags, &code); // Our code
if( rc != errSecSuccess ){
	// boo boo
	syslog(LOG_ERR,"Code Sign check: CopySelf err %d",(int)rc);
	exit(1);
	}

// get the static code (disk bundle)
rc= SecCodeCopyStaticCode(code,kSecCSDefaultFlags, &staticcode);
if( rc != errSecSuccess ){
	// boo boo
	syslog(LOG_ERR,"Code Sign check: CopyStaticCode err %d",(int)rc);
	exit(1);
	}

// Validate the static code 
rc= SecStaticCodeCheckValidity(staticcode, kSecCSDefaultFlags,NULL);
	fprintf(stderr,"validate static code err: %d\n",(int) rc);


}
