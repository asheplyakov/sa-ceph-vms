#!/bin/sh
set -e
MYSELF="${0##*/}"
listen="*:18181"
if [ -n "$*" ]; then
	listen="$*"
fi
osd_pid=`pgrep ceph-osd`
if [ -z "$osd_pid" ]; then
	echo "*** $MYSELF: Error: couldn't find running ceph-osd" >&2
	exit 1
fi
exec gdbserver $listen --attach $osd_pid
