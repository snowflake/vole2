# export the repository to git.

dir=../../vole-git
marks=/tmp/marks

all:
	mkdir -p ${dir}
	fossil export --git  > /tmp/vex
	
	cat /tmp/vex \
	| ( cd ${dir} && git init && git fast-import --quiet  )
