#!/bin/sh
set -e

OSD_ID="$1"
MYDIR="${0%/*}"

OSD_GDB_PORT=18181
OSD_IP="10.253.0.$((3+OSD_ID))"
CEPH_VERSION="0.94.3"

prepare_gdbscript ()
{
	local out="$1"
	sed -r \
 		-e "s/@OSD_IP@/${OSD_IP}/g" \
		-e "s/@OSD_GDB_PORT@/${OSD_GDB_PORT}/g" \
		-e "s/@CEPH_VERSION@/${CEPH_VERSION}/g" \
		${MYDIR}/osd-debug.gdb.in > "$out"
}

gdbscript="osd${OSD_ID}-debug.gdb" 
prepare_gdbscript "$gdbscript"
exec gdb --silent -iex "source $gdbscript"

