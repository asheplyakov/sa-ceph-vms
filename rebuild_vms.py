#!/usr/bin/env python

import optparse
import os
import subprocess
from virtutils import destroy_vm, start_vm
from get_vm_harddrives import get_vm_harddrives
from gen_cloud_conf import generate_cc
from provision_vm import provision
from web_callback_provision import run_web_callback

## --- configuration section starts here --- ##
MONS = ['saceph-mon', 'saceph-mon2', 'saceph-mon3']
OSDS = ['saceph-osd1', 'saceph-osd2', 'saceph-osd3']
RGWS = ['saceph-rgw']
CLIENTS = ['saceph-adm']

CLOUD_CONF_DATA = {
    'ceph_release': 'jewel',
    'distro_release': 'trusty',
    'http_proxy': 'http://sahost:3128/',
    'host_name': 'sahost',
    'web_callback_url': 'http://sahost:8080/',
    'swap_size': 4096,
    'swap_label': 'MOREVM',
}
HOST_PATH_FILTER = '*-os'
WEB_CALLBACK_ADDR = '0.0.0.0:8080'
SOURCE_IMAGE = '/srv/data/Public/img/{distro_release}-server-cloudimg-amd64-disk1.img.raw'\
    .format(distro_release=CLOUD_CONF_DATA['distro_release'])
SOURCE_IMAGE_URL = 'https://cloud-images.ubuntu.com/{distro_release}/current/{distro_release}-server-cloudimg-amd64-disk1.img'\
    .format(distro_release=CLOUD_CONF_DATA['distro_release'])
## --- configuration section ends here --- ##


def _rebuild_vm(vm_name,
                source_image=None,
                cloud_conf_data=None,
                host_path_filter=None):
    generate_cc(cloud_conf_data, vm_name=vm_name)
    vdisk = get_vm_harddrives(vm_name, host_path_filter=host_path_filter)[0]
    destroy_vm(vm_name)
    provision([vdisk],
              img=source_image,
              swap_size=cloud_conf_data['swap_size'] * 1024 * 2,
              swap_label=cloud_conf_data['swap_label'])


def rebuild_vms(vm_list,
                source_image=SOURCE_IMAGE,
                cloud_conf_data=CLOUD_CONF_DATA,
                host_path_filter=HOST_PATH_FILTER,
                web_callback_addr=WEB_CALLBACK_ADDR,
                parallel=0):
    if not parallel:
        parallel = len(vm_list)
    for vm in vm_list:
        _rebuild_vm(vm,
                    source_image=source_image,
                    cloud_conf_data=cloud_conf_data,
                    host_path_filter=host_path_filter)

    for x in range(0, len(vm_list), parallel):
        vm_sublist = vm_list[x:x + parallel]
        for vm in vm_sublist:
            start_vm(vm)
        run_web_callback([web_callback_addr], vms2wait=vm_sublist)


def fetch_cloud_img(img_url=SOURCE_IMAGE_URL,
                    img_dst=SOURCE_IMAGE,
                    force=False):
    if os.path.isfile(img_dst) and not force:
        return img_dst
    orig_img = img_dst.rsplit('.raw', 1)[0]
    if not os.path.isfile(orig_img) or force:
        subprocess.check_call(['wget', '-N', '-O', orig_img, img_url])
    cmd = 'qemu-img convert -f qcow2 -O raw'.split()
    cmd.extend([orig_img, '{}.tmp'.format(img_dst)])
    subprocess.check_call(cmd)
    os.rename('{}.tmp'.format(img_dst), img_dst)


def main():
    parser = optparse.OptionParser()
    parser.add_option('-i', '--image', dest='source_image',
                      default=SOURCE_IMAGE,
                      help='source image (Ubuntu cloud image), must be raw')
    parser.add_option('-l', '--listen', dest='web_callback_addr',
                      default=WEB_CALLBACK_ADDR,
                      help='address to listen for web callback')
    parser.add_option('-u', '--cloud-image-url', dest='cloud_image_url',
                      default=SOURCE_IMAGE_URL,
                      help='fetch Ubuntu cloud image from this URL')
    parser.add_option('-f', '--force-fetch', dest='force_refresh_cloud_img',
                      default=False, action='store_true',
                      help='forcibly refresh Ubuntu cloud image')
    parser.add_option('-j', '--parallel', dest='parallel',
                      type=int, default=0,
                      help='concurrency level (default: # of VMs)')
    options, vm_list = parser.parse_args()
    if not vm_list:
        vm_list.extend(MONS)
        vm_list.extend(OSDS)
        vm_list.extend(RGWS)
        vm_list.extend(CLIENTS)
    fetch_cloud_img(img_dst=options.source_image,
                    img_url=options.cloud_image_url,
                    force=options.force_refresh_cloud_img)
    rebuild_vms(vm_list,
                source_image=options.source_image,
                web_callback_addr=options.web_callback_addr,
                parallel=options.parallel)


if __name__ == '__main__':
    main()
