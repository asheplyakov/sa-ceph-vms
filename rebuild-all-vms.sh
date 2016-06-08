#!/bin/sh
set -e
MYDIR="${0%/*}"
ADM="saceph-adm"
MONS="saceph-mon saceph-mon2 saceph-mon3"
RGW="saceph-rgw"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

exec ${MYDIR}/rebuild-vm.sh $ADM $MONS $OSDS $RGW
