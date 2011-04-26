#import <stddef.h>
#import "sanitise_string.h"
#import "sanitise_string_private.h"

char           *
sanitise_string(char *p)
{

	/*
	 * remove chars not defined by Windows CP1252 from C-strings before
	 * feeding them to NSString conversion routines
	 */
	char           *cp = p;
	unsigned char		c;
	if (p == NULL)
		return p;
	while ((c = *cp) != '\0')
		*cp++ = cp1252_table[c];
	return p;
}
