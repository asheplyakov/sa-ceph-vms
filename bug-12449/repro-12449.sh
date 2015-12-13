#!/bin/sh
set -e

CACHE_SIZE='100000000'
ceph osd pool create simple 64
ceph osd pool create quotap 64
ceph osd pool create base 64
ceph osd pool create cache 64
ceph osd pool set-quota cache max_bytes $CACHE_SIZE
ceph osd pool set-quota quotap max_bytes $CACHE_SIZE
ceph osd tier add base cache
ceph osd tier cache-mode cache writeback
ceph osd tier set-overlay base cache
ceph osd pool set cache hit_set_type bloom
ceph osd pool set cache hit_set_count 1
ceph osd pool set cache hit_set_period 3600
ceph osd pool set cache target_max_bytes $CACHE_SIZE

for n in `seq 1 3`; do
	osd_host="saceph-osd${n}"
	# Collect the most verbose logs from osd, filestore, and journal
	ssh $osd_host "ceph daemon osd.$((n-1)) config set debug_osd 20/20" 
	ssh $osd_host "ceph daemon osd.$((n-1)) config set debug_filestore 20/20"
	ssh $osd_host "ceph daemon osd.$((n-1)) config set debug_journal 20/20" 
	ssh $osd_host "ceph daemon osd.$((n-1)) config set debug_optracker 20/20"
done

