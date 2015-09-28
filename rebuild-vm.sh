#!/bin/sh
set -e
MYSELF="${0##*/}"

vm="$1"

if [ -z "$1" ]; then
	echo "$MYSELF: Error: no VM has been specified" >&2
	exit 1
fi

UBUNTU_RELEASE="vivid"
UBUNTU_IMG="/srv/data/Public/img/${UBUNTU_RELEASE}-server-cloudimg-amd64-disk1.img"
UBUNTU_IMG_URL="https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64-disk1.img"

if [ ! -f "$UBUNTU_IMG" ]; then
	wget -N -O "$UBUNTU_IMG" "$UBUNTU_IMG_URL"
fi


cd "${0%/*}"
virsh destroy "$vm" || true
if ! virsh domid "$vm" >/dev/null 2>&1; then
	virsh define "${vm}.xml"
fi
rm -f "${vm}.qcow2"
cp -a $UBUNTU_IMG "${vm}.qcow2"
./mkconfdrive "$vm"
exec virsh start "$vm"
