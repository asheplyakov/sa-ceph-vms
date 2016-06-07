#!/bin/sh
set -e

MY_DIR="${0%/*}"
MYSELF="${0##*/}"
VM_NAME="$1"

cd "$MY_DIR"
if [ -f "config-drive/common.conf" ]; then
	. config-drive/common.conf
fi

top_build_dir="${MY_DIR}/.build/config-drive"
template_dir="${MY_DIR}/config-drive/template"


_subs () {
	local vm_name="$1"
	local part="$2"
	local template="$template_dir/openstack/latest/$part"
	local dst="$top_build_dir/$vm_name/openstack/latest/$part"
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

_make_alt_copy () {
	local vm_name="$1"
	local alt_data_dir="$top_build_dir/$vm_name/openstack/2012-08-10"
	local data_dir="$top_build_dir/$vm_name/openstack/latest"
	mkdir -p "$alt_data_dir"
	cp -a --target-directory="$alt_data_dir" \
		"$data_dir/user_data" \
		"$data_dir/meta_data.json"
}

genconf () {
	local vm_name="$1"
	local dst_dir="$top_build_dir/$vm_name/openstack/latest"
	mkdir -p "$dst_dir"
	_subs "$vm_name" user_data
	_subs "$vm_name" meta_data.json
	_make_alt_copy "$vm_name"

}

mkconfigdrive() {
	local vm_name="$1"
	local build_dir="$top_build_dir/$vm_name"
	local iso="${vm_name}-config.iso"
	genconf "$vm_name"
	genisoimage -quiet \
		-output "${iso}.tmp" \
		-input-charset utf-8 \
		-volid 'config-2' \
		-joliet -rock \
		"${build_dir}"
	mv "${iso}.tmp" "$iso"
}

mkconfigdrive "$VM_NAME"

