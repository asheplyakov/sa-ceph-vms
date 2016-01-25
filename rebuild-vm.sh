#!/bin/sh
set -e
MYSELF="${0##*/}"
CALLBACK_PORT=3333

vm="$1"

if [ -z "$1" ]; then
	echo "$MYSELF: Error: no VM has been specified" >&2
	exit 1
fi

UBUNTU_IMG="/srv/data/Public/img/trusty-server-cloudimg-amd64-disk1.img"
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img"

if [ ! -f "$UBUNTU_IMG" ]; then
	wget -N -O "$UBUNTU_IMG" "$UBUNTU_IMG_URL"
fi

cd "${0%/*}"
virsh destroy "$vm" || true
if ! virsh domid "$vm" >/dev/null 2>&1; then
	virsh define "${vm}.xml"
fi

vm_drives="`./get-vm-harddrives $vm`"
vm_hdd=''
for hd in $vm_drives; do
	case $hd in
		*-os)
			vm_hdd="$hd"
			;;
	esac
done

if [ -z "$vm_hdd" ]; then
	echo "${MYSELF}: could not find VM hdd backing device" >&2
	exit 1
fi

sudo chgrp adm "$vm_hdd"
dd if=/dev/zero of="$vm_hdd" bs=1M count=32
virt-resize --expand /dev/sda1 "$UBUNTU_IMG" "$vm_hdd"
./mkconfdrive "$vm"
virsh start "$vm"

echo "${MYSELF}: waiting for $vm to call back" >&2

nc -l -p $CALLBACK_PORT | while read line; do
	if [ "$line" != "ready" ]; then
		echo "${MYSELF}: failed to rebuild VM $vm" >&2
		exit 1
	fi
done

