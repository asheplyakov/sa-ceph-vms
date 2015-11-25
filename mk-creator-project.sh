#!/bin/sh
# ceph: create project files for Qt creator
set -ex
MYNAME="${0##*/}"

src_dir=''
projname=''
do_open=''

for arg; do
	case $arg in
		-n|--project-name)
			shift
			projname="$1"
			;;
		-s|--src-dir)
			shift
			src_dir="$1"
			;;
		-o|--open)
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

find . -type f -name '*.cc' -or -name '*.[ch]pp' -or -name '*.[ch]' | \
	grep -v -E '^\.\/\.pc' > ${projname}.files

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


