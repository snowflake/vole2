#!/usr/bin/awk -f

# DJE 8/2/2018
# Script to generate the Wiki page to show help for various Vole releases, plus
#  the latest development.


BEGIN {
        oldhelp="[/doc/RELEASE-%s/Vienna/English.lproj/Vienna%%20Help/index.html|%s]\n\n"
# help is now in a proper Help Book
        newhelp="[/doc/RELEASE-%s/Vienna/Vole.help/Contents/Resources/English.lproj/Vole.html|%s]\n\n"
            
	printf "<h1>Vole Application Help</h1>\n\n"
        printf "Here you will find the Help documents for various releases.\n\n"
        printf("[/doc/trunk/Vienna/Vole.help/Contents/Resources/English.lproj/Vole.html|Latest Development] (probably not yet released).\n\n");
        
	}

	{
            sub("RELEASE-","",$1);
            if(versionnumbercompare($1, "1.6.21") == 1){
                # new help book
                os=newhelp;
            } else {
                os=oldhelp;
            }
            printf(os, $1, $1);
            
            

	}
        function versionnumbercompare( v1, v2){
            split( v1, x1, /\./);
            split( v2, x2, /\./);
#            printf("%d %d %d, %d %d %d\n", x1[1], x1[2], x1[3], x2[1], x2[2], x2[3]);
            # test major
            f=1;
            if( (0 + x1[f]) > (0 + x2[f])) return  1;
            if( (0 + x1[f]) < (0 + x2[f])) return -1;
            # major is the same, now test minor
            f=2
            if( (0 + x1[f]) > (0 + x2[f])) return  1;
            if( (0 + x1[f]) < (0 + x2[f])) return -1;
            # major and minor are the same, test patchlevel
            f=3;
            if( (0 + x1[f]) > (0 + x2[f])) return  1;
            if( (0 + x1[f]) < (0 + x2[f])) return -1;
            # versions are identical, return 0
            return 0;
        }
