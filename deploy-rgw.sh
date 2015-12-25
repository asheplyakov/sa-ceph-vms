#!/bin/sh
set -e
set -x

ADM="saceph-adm"
RGW="saceph-rgw"
MON="saceph-mon"
OSDS="saceph-osd1 saceph-osd2 saceph-osd3"

main_keyring='/etc/ceph/ceph.client.admin.keyring'
rgw_keyring='/etc/ceph/ceph.client.radosgw.keyring'
ceph-authtool --create-keyring "$rgw_keyring"
chmod +r "$rgw_keyring"
ceph-authtool "$rgw_keyring" -n client.radosgw.gateway --gen-key
ceph-authtool -n client.radosgw.gateway --cap osd 'allow rwx' --cap mon 'allow rwx' "$rgw_keyring"
ceph -k "$main_keyring" auth add client.radosgw.gateway -i "$rgw_keyring" 
ssh "$RGW" mkdir -p -m 755 /etc/ceph
scp -p "$rgw_keyring" ${RGW}:/etc/ceph

RGW_POOLS=""
RGW_POOLS="$RGW_POOLS rgw.root rgw.control rgw.gc"
RGW_POOLS="$RGW_POOLS rgw.buckets rgw.buckets.index rgw.buckets.extra"
RGW_POOLS="$RGW_POOLS log intent-log usage"
RGW_POOLS="$RGW_POOLS users users.email users.swift users.uid"

for pool in $RGW_POOLS; do
	ceph osd pool create ".${pool}" 32 32 replicated
done

cat >> /etc/ceph/ceph.conf <<-EOF
[client.radosgw.gateway]
host = $RGW
keyring = $rgw_keyring
rgw socket path = ""
log file = /var/log/radosgw/client.radosgw.gateway.log
rgw frontends = fastcgi socket_port=9000 socket_host=0.0.0.0
rgw print continue = false
EOF

ceph-deploy --overwrite-conf config pull $ADM

ceph-deploy --overwrite-conf config push $MON $OSDS $RGW

scp -p "$main_keyring" "${RGW}:/etc/ceph"

ssh $RGW mkdir -p -m 755 /var/lib/ceph/radosgw/ceph-radosgw.gateway

ssh $RGW service radosgw stop || true
ssh $RGW service radosgw start

ssh $RGW apt-get install -y apache2
scp -p ${RGW}:/etc/apache2/apache2.conf .
echo "ServerName $RGW" > apache2.conf.new
cat apache2.conf >> apache2.conf.new
scp -p apache2.conf.new $RGW:/etc/apache2/apache2.conf
ssh $RGW a2enmod rewrite
ssh $RGW a2enmod proxy_fcgi

cat > rgw.conf <<-EOF
<VirtualHost *:80>
ServerName localhost
DocumentRoot /var/www/html

ErrorLog /var/log/apache2/rgw_error.log
CustomLog /var/log/apache2/rgw_access.log combined

RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]

SetEnv proxy-nokeepalive 1
ProxyPass / fcgi://localhost:9000/

</VirtualHost>
EOF

scp -p rgw.conf ${RGW}:/etc/apache2/conf-available/rgw.conf
ssh $RGW a2enconf rgw
ssh $RGW service apache2 restart

testuser="testuser"
ssh $RGW radosgw-admin user create --uid="${testuser}" --display-name='TestUser'
ssh $RGW radosgw-admin subuser create --uid="${testuser}" --subuser="${testuser}:swift" --access=full

create_swift_secret_key () {
	local user="$1"
	local reply="`ssh $RGW radosgw-admin key create --subuser="${user}:swift" --key-type=swift --gen-secret`"
	python <<-EOF
	import json
	out = json.loads("""$reply""")
	print(out['swift_keys'][0]['secret_key'])
	EOF
}

swift_secret_key=`create_swift_secret_key $testuser`
apt-get install -y python-swiftclient
dd if=/dev/zero of=swift.test bs=1M count=1
swift -A http://${RGW}/auth/1.0 -U "${testuser}:swift" -K "$swift_secret_key" upload my-first-bucket swift.test
swift -A http://${RGW}/auth/1.0 -U "${testuser}:swift" -K "$swift_secret_key" list my-first-bucket

