#!/usr/bin/env python

import os
import subprocess
from xml.etree import ElementTree


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


def _get_device_ip(net_dev_xml):
    mac = _get_device_mac(net_dev_xml)
    source_net = _get_source_network(net_dev_xml)
    leases_file_name = _get_leases_file_name(source_net)
    return _get_leased_ip_by_mac(mac, leases_file_name)


def _get_domain_ips(dom_xml):
    net_devices = _enumerate_network_devices(dom_xml)
    return (ip for ip in (_get_device_ip(dev) for dev in net_devices)
            if ip is not None)


def get_domain_ips(name, conn=None):
    if conn is None:
        conn = 'qemu:///system'
    out = subprocess.check_output(['virsh', '-c', conn, 'dumpxml', name])
    dom_xml = ElementTree.fromstring(out)
    return _get_domain_ips(dom_xml)


def update_known_hosts(ips=None, hostname=None, ssh_key=None):
    if ips is None:
        ips = list(get_domain_ips(hostname))
    known_hosts_file = os.path.expanduser('~/.ssh/known_hosts')
    for addr in ips:
        subprocess.call(['ssh-keygen', '-f', known_hosts_file, '-R', addr])

    if ssh_key:
        with open(known_hosts_file, 'a') as f:
            for addr in ips:
                f.write('{0},{1} {2}\n'.format(hostname, addr, ssh_key))
