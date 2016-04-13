#!/bin/sh
set -e
ADM="saceph-adm"
MON="saceph-mon"
RGW="saceph-rgw"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

mkdir -p -m 0755 ~/.ssh
if [ -f ~/.ssh/known_hosts ]; then
for node in $MON $OSDS $ADM $RGW; do
	ssh-keygen -f ~/.ssh/known_hosts -R "$node"
done
fi
for node in $MON $OSDS $ADM $RGW; do
	ssh-keyscan -t rsa $node
done >> ~/.ssh/known_hosts

ceph-deploy --overwrite-conf purge $MON $OSDS $RGW $ADM
ceph-deploy --overwrite-conf purgedata  $MON $OSDS $RGW $ADM
ceph-deploy --overwrite-conf forgetkeys

ceph-deploy --overwrite-conf new $MON
ceph-deploy --overwrite-conf install $MON $OSDS $ADM $RGW
ceph-deploy --overwrite-conf mon create-initial
for osd in $OSDS; do
	ceph-deploy --overwrite-conf disk zap ${osd}:vdb
	ceph-deploy --overwrite-conf disk zap ${osd}:vdc
	disk=$(ssh $osd find /dev/disk/by-id -type l -name 'virtio-*_DAT00?')
	journal=$(ssh $osd find /dev/disk/by-id -type l -name 'virtio-*_JOURNA')
	if [ -z "$disk" ]; then
		echo "node $osd: can't find data HD" >&2
		exit 1
	fi
	if [ -z "$journal" ]; then
		echo "node $osd: can't find journal HD" >&2
		exit 1
	fi
	ceph-deploy --overwrite-conf osd prepare ${osd}:${disk}:${journal}
	ceph-deploy --overwrite-conf osd activate ${osd}:${disk}-part1:${journal}-part1
done

ceph-deploy --overwrite-conf admin $ADM $MON $OSDS

ceph health
