#!/bin/sh
set -e
MYSELF="${0##*/}"
CALLBACK_PORT=3333

vm="$1"

if [ -z "$1" ]; then
	echo "$MYSELF: Error: no VM has been specified" >&2
	exit 1
fi

cd "${0%/*}"
if [ -f config-drive/common.conf ]; then
	. config-drive/common.conf
fi
if [ -z "$distro_release" ]; then
	distro_release='xenial'
fi

UBUNTU_IMG="/srv/data/Public/img/${distro_release}-server-cloudimg-amd64-disk1.img.raw"
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/${distro_release}/current/${distro_release}-server-cloudimg-amd64-disk1.img"

if [ ! -f "$UBUNTU_IMG" ]; then
	ORIG_UBUNTU_IMG="${UBUNTU_IMG%.raw}"
	if [ ! -f "$ORIG_UBUNTU_IMG" ]; then
		wget -N -O "$ORIG_UBUNTU_IMG" "$UBUNTU_IMG_URL"
	fi
	qemu-img convert -f qcow2 -O raw "$ORIG_UBUNTU_IMG" "${UBUNTU_IMG}.tmp"
	mv "${UBUNTU_IMG}.tmp" "${UBUNTU_IMG}"
fi


./gen-cloud-conf.sh "$vm"
./mkconfdrive "$vm"

maybe_shutdown () {
	local state=''
	if ! virsh domid "$vm" >/dev/null 2>&1; then
		virsh define "${vm}.xml"
		return
	fi
	state=`virsh domstate $vm`
	case "$state" in
		running)
			virsh destroy "$vm"
			;;
	esac
}


# LVs for OS installation are named '*-os'
vm_hdd="`./get-vm-harddrives -f '*-os' $vm`"
if [ -z "$vm_hdd" ]; then
	echo "${MYSELF}: could not find VM hdd backing device" >&2
	exit 1
fi

maybe_shutdown
./provision-vm -i "$UBUNTU_IMG" -d "$vm_hdd"

virsh start $vm
echo "${MYSELF}: waiting for $vm to call back" >&2

nc -l -p $CALLBACK_PORT | while read line; do
	if [ "$line" != "ready" ]; then
		echo "${MYSELF}: failed to rebuild VM $vm" >&2
		exit 1
	fi
done

