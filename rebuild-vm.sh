#!/bin/sh
set -e
MYSELF="${0##*/}"

cd "${0%/*}"
if [ -f config-drive/common.conf ]; then
	. config-drive/common.conf
fi
if [ -z "$distro_release" ]; then
	distro_release='xenial'
fi

UBUNTU_IMG="/srv/data/Public/img/${distro_release}-server-cloudimg-amd64-disk1.img.raw"
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/${distro_release}/current/${distro_release}-server-cloudimg-amd64-disk1.img"

maybe_fetch_cloud_img () {
	local ORIG_UBUNTU_IMG="${UBUNTU_IMG%.raw}"
	if [ ! -f "$ORIG_UBUNTU_IMG" ]; then
		wget -N -O "$ORIG_UBUNTU_IMG" "$UBUNTU_IMG_URL"
	fi
	if [ ! -f "$UBUNTU_IMG" ]; then
		qemu-img convert -f qcow2 -O raw "$ORIG_UBUNTU_IMG" "${UBUNTU_IMG}.tmp"
		mv "${UBUNTU_IMG}.tmp" "${UBUNTU_IMG}"
	fi
}

maybe_shutdown () {
	local vm="$1"
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

rebuild_vm () {
	local vm="$1"
	local vm_hdd
	./gen-cloud-conf.sh "$vm"
	# LVs for OS installation are named '*-os'
	vm_hdd="`./get-vm-harddrives -f '*-os' $vm`"
	if [ -z "$vm_hdd" ]; then
		echo "${MYSELF}: could not find $vm drive backing device" >&2
		exit 1
	fi
	maybe_shutdown "$vm"
	./provision-vm -i "$UBUNTU_IMG" -d "$vm_hdd"
}

main () {
	local vms="$*"
	local vms_comma_sep_list
	local IFS=','
	vms_comma_sep_list="$*"
	unset IFS

	for vm in $vms; do
		rebuild_vm $vm
	done

	for vm in $vms; do
		virsh start $vm
		echo "${MYSELF}: waiting for  $vm to call back" >&2
		./web-callback-provision.py -m "$vm"
	done
}

maybe_fetch_cloud_img
main $@
