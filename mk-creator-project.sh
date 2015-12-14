#!/bin/sh
# ceph: create project files for Qt creator
set -ex
MYNAME="${0##*/}"

src_dir=''
projname=''
do_open=''

print_help() {
	cat <<-EOF
	Usage: ${MYNAME} [-s src_dir] [-n project_name] [-o] [-h]
	Create Qt Creator project files for Ceph and optionally open project

	-s	directory where Ceph code is located
	-n	name of the project to be displayed in Qt Creator
	-o	open the project in Qt Creator
	-h	print this text and exit
	EOF
}

while getopts "hon:s:" OPT; do
	case "$OPT" in
		h)
			print_help
			exit 0
			;;
		s)
			src_dir="$OPTARG"
			;;
		n)
			projname="$OPTARG"
			;;
		o)
			do_open='yes'
			;;
	esac
done

if [ -z "$src_dir" ]; then
	src_dir="`pwd`"
fi

if [ ! -d "$src_dir" ]; then
	echo "$MYNAME: no such directory: $src_dir" >&2
	exit 1
fi

if [ -z "$projname" ]; then
	projname="${src_dir##*/}"
fi

cd "${src_dir}"

if [ -d '.git' ]; then
	git ls-files '*.cc' '*.[ch]' '*.[ch]pp' | sort -u > ${projname}.files
else
	find . -type f -name '*.cc' -or -name '*.[ch]pp' -or -name '*.[ch]' | \
		grep -v -E '^\.\/\.pc' > ${projname}.files
fi

cat > ${projname}.includes <<-EOF
src
EOF
cat > ${projname}.config <<-EOF
#define HAVE_LIBAIO 1
EOF

touch ${projname}.creator

if [ -n "$do_open" ]; then
	exec qtcreator "${projname}.creator"
fi


