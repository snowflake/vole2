#!/bin/sh

# prompts user for yes or no
# returns true if Y or y
# $1 = prompt string

read -p "$1" yesno
case ${yesno} in 
	[Yy] ) exit 0 ;;
	esac
exit 1


