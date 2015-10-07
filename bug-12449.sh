#!/bin/sh
set -e

CACHE_SIZE='100000000'
ceph osd pool create base 64
ceph osd pool create cache 64
ceph osd pool set-quota cache max_bytes $CACHE_SIZE
ceph osd tier add base cache
ceph osd tier cache-mode cache writeback
ceph osd tier set-overlay base cache
ceph osd pool set cache hit_set_type bloom
ceph osd pool set cache hit_set_count 1
ceph osd pool set cache hit_set_period 3600
ceph osd pool set cache target_max_bytes $CACHE_SIZE

dd if=/dev/zero of=200m.dat bs=1M count=200

rados put -p base x1 200m.dat || true
rados put -p base x1 200m.dat || true

