#!/bin/sh
set -e
ADM="saceph-adm"
MON="saceph-mon saceph-mon2 saceph-mon3"
RGW="saceph-rgw"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

mkdir -p -m 0755 ~/.ssh
for node in $MON $OSDS $ADM; do
	ssh-keyscan -t rsa $node
done > ~/.ssh/known_hosts

ceph-deploy --overwrite-conf purge $MON $OSDS $ADM
ceph-deploy --overwrite-conf purgedata  $MON $OSDS $ADM
ceph-deploy --overwrite-conf forgetkeys

ceph-deploy --overwrite-conf new $MON
ceph-deploy --overwrite-conf install $ADM $MON $OSDS
ceph-deploy --overwrite-conf mon create-initial

for osd in $OSDS; do
	for disk in $(ssh $osd find /dev/disk/by-id -type l -name '*_DATA'| sort -n); do
		journal="${disk%_DATA}_JOURNAL"
		ceph-deploy disk zap ${osd}:${disk}
		ceph-deploy disk zap ${osd}:${journal}
		ceph-deploy osd prepare ${osd}:${disk}:${journal}
		ceph-deploy osd activate ${osd}:${disk}-part1:${journal}-part1
	done
done

ceph-deploy admin $ADM $MON $OSDS

ceph health

# compatibility with in-kernel (Linux 3.13) RBD client
ceph osd getcrushmap -o crush.bak
crushtool -i crush.bak -o crush.new --set-chooseleaf-vary-r 0
ceph osd setcrushmap -i crush.new

cat >> /etc/ceph/ceph.conf <<-EOF

[client]
rbd default features = 3

EOF
