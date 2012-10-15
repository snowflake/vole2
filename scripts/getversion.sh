#!/bin/sh
PATH=${DEVELOPER_DIR}/usr/bin:${PATH}

# get the version from Info.plist

agvtool mvers |  tr '"' '|' \
	| awk  'BEGIN { FS="|" } /Found CFBundle/ { printf "%s", $2 }'
