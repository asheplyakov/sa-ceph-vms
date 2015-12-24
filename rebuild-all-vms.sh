#!/bin/sh
set -e
MYDIR="${0%/*}"
ADM="saceph-adm"
MONS="saceph-mon"
RGW="saceph-rgw"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

for node in $MONS $OSDS $RGW $ADM; do
	${MYDIR}/rebuild-vm.sh $node
done
