//
//  smart-utf.h
//  Vole_xc5
//
//  Created by David Evans on 19/08/2014.
//
//

#ifndef Vole_xc5_smart_utf_h
#define Vole_xc5_smart_utf_h

// This file will define various switches for Smart-UTF-8

#define SMARTUTF_DATABASE_READ 1

#ifdef SMARTUTF_DATABASE_READ
#define DATABASE_STRING_ENCODING NSUTF8StringEncoding
#endif


#endif
