/*
 * convert a string to utf - 8. The string can contain CP1252 or UTF - 8
 * sequences.CP1252 will be converted to UTF-8
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "utf8-process.h"
#include "cp1252utf8.h"

#define UNICODE_MAX	0x10FFFF
#define MIN_SURROGATE 	0xD800
#define MAX_SURROGATE   0xDFFF
int		unicode_min[] = {0, 0, 0x80, 0x800, 0x10000};	/* min values for each
								 * sequence */
int		initial_mask[] = {0, 0x7f, 0x1f, 0x0f, 0x7};	/* mask values for the
								 * initial byte */

#define valid_tail(in) ((input[in] & 0xc0 ) == 0x80)
#define copy() 		*output++ = input[i++]

static int
check_utf8(int length, unsigned char *buff)
{
    /*
     * Check the UTF-8 sequence at buff, length is the sequence length.
     * Returns 0 if OK, 1 if >MAX, 2 if overlong, 3 if surrogate
     */
    int		    rc = -1;
    int		    i;
    int		    codepoint = 0;
    codepoint = (*buff++ & initial_mask[length]);
    for (i = length; i > 1; i--) {
	codepoint = (codepoint << 6) | (*buff++ & 0x3f);
    }
    if (codepoint > UNICODE_MAX || codepoint < 0)
	rc = 1;
    else if (codepoint < unicode_min[length])
	rc = 2;			/* overlong seq */
    else if (codepoint >= MIN_SURROGATE && codepoint <= MAX_SURROGATE)
	rc = 3;			/* surrogate */
    else
	rc = 0;
#if 0
    fprintf(stderr, "codepoint = %x, rc = %d \n", codepoint, rc);
#endif
    return rc;
}



/*
 * returns a malloc'ed buffer, which must be free'd after use
 */
char           *
utf8process(unsigned char *input)
{

    if (input == NULL)
	return (NULL);

    size_t	    end = strlen((char *)input);
    unsigned char           *base = malloc((end * 4) + 1);
    if (base == NULL)
	return (NULL);
    unsigned char           *output = base;

    size_t	    i;
    for (i = 0; i < end;) {
	if ((input[i] & 0x80) == 0) {
	    /* It 's ASCII */
	    copy();
	    continue;
	}
	/* Look for multibyte sequences */
	if (((input[i] & 0xE0) == 0xC0) && valid_tail(i + 1)) {
	    /* 2 byte sequence */
	    if (check_utf8(2, input + i))
		goto cp1252;
	    copy();
	    copy();
	    continue;
	}
	if (((input[i] & 0xF0) == 0xE0) && valid_tail(i + 1) && valid_tail(i + 2)) {
	    /* 3 byte sequence */
	    if (check_utf8(3, input + i))
		goto cp1252;
	    copy();
	    copy();
	    copy();
	    continue;
	}
	if (((input[i] & 0xF8) == 0xF0)
	    && valid_tail(i + 1) && valid_tail(i + 2) &&
	    valid_tail(i + 3)) {
	    /* 4 byte sequence */
	    if (check_utf8(4, input + i))
		goto cp1252;
	    copy();
	    copy();
	    copy();
	    copy();
	    continue;
	}
cp1252:
	/* Assume it is genuine cp1252 */
	strcpy( (char *)output, codetable[input[i]].utf8bytes);
	output += codetable[input[i]].nbytes;
	i++;
	continue;

    }
    *output = '\0';
    /* terminate the string; */
    return (char *)base;
}
