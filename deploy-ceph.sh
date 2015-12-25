#!/bin/sh
set -e
ADM="saceph-adm"
MON="saceph-mon"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

mkdir -p -m 0755 ~/.ssh
for node in $MON $OSDS; do
	ssh-keyscan -t rsa $node
done >> ~/.ssh/known_hosts

ceph-deploy --overwrite-conf new $MON
ceph-deploy --overwrite-conf install $MON $OSDS
ceph-deploy --overwrite-conf mon create-initial
for osd in $OSDS; do
	ceph-deploy --overwrite-conf disk zap ${osd}:vdb
	ceph-deploy --overwrite-conf disk zap ${osd}:vdc
	ceph-deploy --overwrite-conf osd prepare ${osd}:vdb:/dev/vdc
done

for osd in $OSDS; do
	ceph-deploy --overwrite-conf osd activate ${osd}:/dev/vdb1:/dev/vdc1
done

ceph-deploy --overwrite-conf admin $ADM $MON $OSDS

for node in $MON $OSDS; do
	ssh $node apt-get install -y ceph-dbg
done

ceph health
