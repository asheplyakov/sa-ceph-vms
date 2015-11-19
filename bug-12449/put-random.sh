#!/bin/sh
set -e
cd "${0%/*}"
osd_count=3
counter=0
target_pool="simple"
size=16 # size of a test object in MBs

for arg; do
	case $arg in
		-p|--pool)
			shift
			target_pool="$1"
			;;
		-s|--size)
			shift
			size="$2"
			;;
	esac
done

if [ -f 'counter' ]; then
	counter=`cat counter`
fi
counter=$((counter+1))
echo $counter > counter
payload_file="${TMP:-/tmp}/t${counter}.dat"
dd if=/dev/urandom bs=1M count=${size} of=${payload_file}
if [ -n "$DRY_RUN" ]; then
	DRY_RUN=echo
fi

set -x

for osd_idx in `seq 1 $osd_count`; do
	osd_host="saceph-osd${osd_idx}"
	main_log_file="/var/log/ceph/ceph-osd.$((osd_idx-1)).log"
	log_dump="/tmp/osd-${target_pool}-osd-$((osd_idx-1)).log"
	ssh "$osd_host" /bin/sh -c "\"nohup tail -F $main_log_file > $log_dump&\""
done
rados put t${counter}.dat "${payload_file}" -p $target_pool || true
sleep 5

for osd_idx in `seq 1 $osd_count`; do
	osd_host="saceph-osd${osd_idx}"
	log_dump="/tmp/osd-${target_pool}-osd-$((osd_idx-1)).log"
	ssh $osd_host /bin/sh -c "'pgrep tail | xargs --no-run-if-empty -n1 kill -15'"
	scp -p "$osd_host:${log_dump}" .
done
