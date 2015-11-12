#!/bin/sh
cd "${0%/*}"
counter=0
size="${1:-16}" # size of a test object in MBs
if [ -f 'counter' ]; then
	counter=`cat counter`
fi
counter=$((counter+1))
echo $counter > counter
dd if=/dev/urandom bs=1M count=${size} of=sr4k.dat
set -x
exec rados put t${counter}.dat sr4k.dat -p base
