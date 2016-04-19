#!/bin/sh
#
# IPs:
# mons: [10.253.0.20, 10.253.0.100)
# OSDs: [10.253.0.100, 10.253.0.248)
# rgws: [10.253.0.248, 10.253.0.254]

MY_DIR="${0%/*}"

cd "$MY_DIR"

my_ip='10.253.0.20/24'
my_name='saceph-mon'
net_brd='10.253.0.255'
my_uuid="`uuidgen`"

subs () {
	local file="$1"
	if [ ! -e "$file" ]; then
		exit 1
	fi
	sed -i "$file" \
		-e "s;@my_ip@;${my_ip};g" \
		-e "s;@net_brd@;${net_brd};g" \
		-e "s/@my_name@/${my_name}/g" \
		-e "s/@my_uuid@/${my_uuid}/g"
}

subs openstack/latest/user_data
subs openstack/latest/meta_data.json
