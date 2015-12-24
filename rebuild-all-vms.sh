#!/bin/sh
set -e
MYDIR="${0%/*}"
ADM="saceph-adm"
MONS="saceph-mon"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

for node in $ADM $MONS $OSDS; do
	${MYDIR}/rebuild-vm.sh $node
done
