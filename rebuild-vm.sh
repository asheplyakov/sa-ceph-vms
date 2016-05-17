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

UBUNTU_IMG="/srv/data/Public/img/${distro_release}-server-cloudimg-amd64-disk1.img.nojournal"
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/${distro_release}/current/${distro_release}-server-cloudimg-amd64-disk1.img"

if [ ! -f "$UBUNTU_IMG" ]; then
	ORIG_UBUNTU_IMG="${UBUNTU_IMG%.nojournal}"
	if [ ! -f "$ORIG_UBUNTU_IMG" ]; then
		wget -N -O "$ORIG_UBUNTU_IMG" "$UBUNTU_IMG_URL"
	fi
	set -x
	guestfish --ro -a "$ORIG_UBUNTU_IMG" run : download /dev/sda1 sda1-$$.img
	tune2fs -O ^has_journal sda1-$$.img
	cp -a "$ORIG_UBUNTU_IMG" tmp-$$.img
	guestfish --rw -a tmp-$$.img run : upload sda1-$$.img /dev/sda1
	virt-sparsify --compress tmp-$$.img "${UBUNTU_IMG}.tmp"
	mv "${UBUNTU_IMG}.tmp" "${UBUNTU_IMG}"
	set +x
fi


./gen-cloud-conf.sh "$vm"

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

provision_vm () {
	local vm_hdd="$1"
	local root_start=2048 # sectors
	local drive_size=32 # GB
	local swap_size=4 # GB
	root_size=$((drive_size-swap_size))
	root_end=$((root_start+root_size*1024*1024*2-1))

	# export LIBGUESTFS_DEBUG=1
	# export LIBGUESTFS_TRACE=1
	local verbose=''
	# verbose="--verbose"

	guestfish ${verbose} <<-EOF
		add "$UBUNTU_IMG"
		add "$vm_hdd"
		run
		copy-device-to-device /dev/sda /dev/sdb size:$((512*root_start))
		part-del /dev/sdb 1
		part-add /dev/sdb p ${root_start} ${root_end}
		part-add /dev/sdb p $((root_end+1)) -1
		part-set-mbr-id /dev/sdb 2 0x82
		mkswap-L MOREVM /dev/sdb2
		copy-device-to-device /dev/sda1 /dev/sdb1
		resize2fs /dev/sdb1
	EOF
}

provision_vm $vm_hdd
./mkconfdrive "$vm"
virsh start "$vm"

echo "${MYSELF}: waiting for $vm to call back" >&2

nc -l -p $CALLBACK_PORT | while read line; do
	if [ "$line" != "ready" ]; then
		echo "${MYSELF}: failed to rebuild VM $vm" >&2
		exit 1
	fi
done

