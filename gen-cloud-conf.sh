#!/bin/sh
set -e

MY_DIR="${0%/*}"
MYSELF="${0##*/}"
VM_NAME="$1"

cd "$MY_DIR"
if [ -f "config-drive/common.conf" ]; then
	. config-drive/common.conf
fi

_subs () {
	local vm_name="$1"
	local part="$2"
	local template="config-drive/template/openstack/latest/$part"
	local dst="config-drive/$vm_name/openstack/latest/$part"
	local my_uuid="`uuidgen`"
	sed "$template" \
		-e "s/@my_name@/${vm_name}/g" \
		-e "s/@my_uuid@/${my_uuid}/g" \
		-e "s/@distro_release@/${distro_release}/g" \
		-e "s/@ceph_release@/${ceph_release}/g" \
		-e "s;@http_proxy@;${http_proxy};g" \
	> "${dst}.tmp"
	mv "${dst}.tmp" "$dst"
}

genconf () {
	local vm_name="$1"
	local dst_dir="config-drive/$vm_name/openstack/latest"
	mkdir -p "$dst_dir"
	_subs "$vm_name" user_data
	_subs "$vm_name" meta_data.json
}

genconf "$VM_NAME"

