#!/usr/bin/env python

import os
import subprocess
from xml.etree import ElementTree

DEFAULT_LIBVIRT_CONN = 'qemu:///system'
KNOWN_HOSTS_FILE = os.path.expanduser('~/.ssh/known_hosts')


def _get_device_mac(net_dev_xml):
    mac_node = net_dev_xml.find('mac')
    if mac_node is None:
        raise ValueError('Interface has no mac address [1]')
    mac = mac_node.get('address')
    if mac is None:
        raise ValueError('Interface has no mac address [2]')
    return mac


def _get_source_network(net_dev_xml):
    source_node = net_dev_xml.find('source')
    if source_node is None:
        raise ValueError('Interface is not attached to a network')
    return source_node.get('network')


def _get_leases_file_name(net_name):
    base_dir = '/var/lib/libvirt/dnsmasq/{0}.leases'
    leases_file_name = base_dir.format(net_name)
    return leases_file_name if os.path.exists(leases_file_name) else None


def _enumerate_network_devices(node_xml):
    return node_xml.findall("devices/interface[@type='network']")


def _get_leased_ip_by_mac(mac, leases_file_name):
    if leases_file_name is None:
        return None
    with open(leases_file_name, 'r') as lf:
        for ll in lf:
            # 1429875731 02:23:75:06:69:5a 192.168.122.250 ubuntu-mos *
            time, ifmac, ip, hostname, rest = ll.split()
            if ifmac == mac:
                return ip
    return None


def _get_iface_ip(net_dev_xml, conn=DEFAULT_LIBVIRT_CONN):
    mac = _get_device_mac(net_dev_xml)
    source_net = _get_source_network(net_dev_xml)
    domain_name = get_libvirt_net_domain(source_net, conn=conn)
    leases_file_name = _get_leases_file_name(source_net)
    ip = _get_leased_ip_by_mac(mac, leases_file_name)
    return (ip, domain_name)


def _make_fqdn(vm_name, domain_name=None):
    if domain_name:
        return '{0}.{1}'.format(vm_name, domain_name)
    else:
        return vm_name


def _get_vm_ips(dom_xml, conn=DEFAULT_LIBVIRT_CONN):
    net_devices_xml = _enumerate_network_devices(dom_xml)
    vm_name = dom_xml.find('name').text
    for dev_xml in net_devices_xml:
        ip, domain_name = _get_iface_ip(dev_xml, conn=conn)
        yield (ip, _make_fqdn(vm_name, domain_name=domain_name))


def get_libvirt_net_domain(net_name, conn='qemu:///system'):
    out = subprocess.check_output(['virsh', '-c', conn,
                                   'net-dumpxml', net_name])
    # <network connections='1'>
    #   <name>saceph-priv</name>
    #   <uuid>f231c38f-da75-4977-8928-95be84f9953a</uuid>
    #   <bridge name='br-saceph-priv' stp='on' delay='0'/>
    #   <mac address='52:54:00:b2:7f:37'/>
    #   <domain name='vm.ceph.asheplyakov'/>
    #   <ip address='10.253.0.1' netmask='255.255.255.0'>
    #      <dhcp>
    #         <range start='10.253.0.10' end='10.253.0.254'/>
    #      </dhcp>
    #   </ip>
    # </network>
    net_xml = ElementTree.fromstring(out.strip())
    try:
        domain_xml = net_xml.findall('domain')[0]
        return domain_xml.get('name')
    except IndexError:
        return None


def get_vm_ips(name, conn='qemu:///system'):
    out = subprocess.check_output(['virsh', '-c', conn, 'dumpxml', name])
    dom_xml = ElementTree.fromstring(out)
    return _get_vm_ips(dom_xml, conn=conn)


def vm_exists(vm_name, conn='qemu:///system'):
    try:
        subprocess.check_output(['virsh', '-c', conn, 'domstate', vm_name])
        return True
    except subprocess.CalledProcessError:
        return False


def define_vm(vm_xml=None, raw_vm_xml=None, conn='qemu:///system'):
    if raw_vm_xml is None:
        raw_vm_xml = ElementTree.tostring(vm_xml)
    else:
        vm_xml = ElementTree.fromstring(raw_vm_xml)
    vm_name = vm_xml.find('name').text
    destroy_vm(vm_name, conn=conn, undefine=True)
    proc = subprocess.Popen(['virsh', '-c', conn, 'define', '/dev/stdin'],
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    try:
        out, err = proc.communicate(input=raw_vm_xml)
    except subprocess.CallledProcessError:
        print("define_vm: error: %s" % str(err))
        raise


def destroy_vm(name, conn='qemu:///system', undefine=False):
    try:
        cmd = ['virsh', '-c', conn, 'domstate', name]
        state = subprocess.check_output(cmd).strip()
    except subprocess.CalledProcessError:
        # OK, no such VM
        return
    if state.strip() == 'running':
        remove_vm_ssh_keys(vm_name=name)
        subprocess.check_call(['virsh', '-c', conn, 'destroy', name])
    if undefine:
        subprocess.check_call(['virsh', '-c', conn, 'undefine', name])


def destroy_undefine_vm(name, conn='qemu:///system'):
    destroy_vm(name, conn=conn, undefine=True)


def start_vm(name, conn='qemu:///system'):
    subprocess.check_call(['virsh', '-c', conn, 'start', name])


def check_ssh_known_host(name_or_ip, known_hosts_file=KNOWN_HOSTS_FILE):
    """Check if the known_hosts_file contains ssh key of the given host"""
    try:
        subprocess.check_call(['ssh-keygen', '-F', name_or_ip,
                               '-f', known_hosts_file])
        return True
    except subprocess.CalledProcessError as e:
        if e.returncode == 1:
            return False
        else:
            raise


def remove_ssh_known_host(name_or_ip, known_hosts_file=KNOWN_HOSTS_FILE):
    """Remove ssh keys of the given host from known_hosts_file"""
    if not known_hosts_file:
        known_hosts_file = os.path.expanduser('~/.ssh/known_hosts')
    while check_ssh_known_host(name_or_ip, known_hosts_file=known_hosts_file):
        subprocess.call(['ssh-keygen', '-f', known_hosts_file,
                         '-R', name_or_ip])


def update_known_hosts(ips=None, vm_name=None, ssh_key=None,
                       known_hosts_file=KNOWN_HOSTS_FILE):
    if ips is None:
        ips = list(get_vm_ips(vm_name))
    for ip, fqdn in ips:
        # wipe out the old key (if any)
        remove_ssh_known_host(fqdn)
        # Remove entries having the same IP just in a case. Note that
        # addr might be None for several reasons (VM is down at the moment,
        # network configuration is still in progress, etc)
        if ip:
            remove_ssh_known_host(ip)

    if ssh_key:
        with open(known_hosts_file, 'a') as f:
            for addr, fqdn in ips:
                f.write('{fqdn} {key}\n'.format(fqdn=fqdn, key=ssh_key))
            f.flush()


def remove_vm_ssh_keys(ips=None, vm_name=None,
                       known_hosts_file=KNOWN_HOSTS_FILE):
    update_known_hosts(ips=ips, vm_name=vm_name, ssh_key=None,
                       known_hosts_file=known_hosts_file)
