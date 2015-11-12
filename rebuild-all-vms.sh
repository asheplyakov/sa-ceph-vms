#!/bin/sh
set -e
MYDIR="${0%/*}"
MONS="saceph-mon"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

for node in $MONS $OSDS; do
	${MYDIR}/rebuild-vm.sh $node
done
