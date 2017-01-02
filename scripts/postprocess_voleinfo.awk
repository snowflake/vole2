#!/usr/bin/awk

# Script to insert UUIDs from the Vole executable
# into the VoleInfo.plist.
# Call with parameter vole = location of Vole executable
# stdin = original VoleInfo.plist,
# stdout = new Voleinfo.plist
# Example:
# cat VoleInfo.plist | awk -f postprocess_voleinfo.awk vole=Vole > NewVoleInfo.plist
# 
# Created 2/1/2017

/<!-- UUID Placeholder -->/ {
    print("  <key>UUID</key>");
    print("    <dict>");
    command = ("dwarfdump --uuid " vole)
    while ((command | getline ) > 0){
        gsub(/\(/,"",$3);
        gsub(/\)/,"",$3);
	printf("      <key>%s</key>\n", $3);
	printf("        <string>%s</string>\n", $2);
    }
    close(command)
    print("    </dict>");
    next;
}
{ print }



