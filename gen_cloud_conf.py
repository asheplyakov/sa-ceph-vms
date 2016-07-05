#!/usr/bin/env python

import jinja2
import optparse
import os
import shutil
import subprocess
import sys
import uuid

from sshutils import get_authorized_keys

MY_DIR = os.path.abspath(os.path.dirname(__file__))
TEMPLATE_DIR = os.path.join(MY_DIR, 'templates/config-drive')


def render_and_save(data, vm_name=None, tmpl_dir=TEMPLATE_DIR):
    base_dir = '.build/config-drive/{0}'.format(vm_name)
    base_dir = os.path.join(MY_DIR, base_dir)
    out_dir = os.path.join(base_dir, 'openstack/latest')
    alt_dir = os.path.join(base_dir, 'openstack/2012-08-10')
    for tdir in (out_dir, alt_dir):
        if not os.path.isdir(tdir):
            os.makedirs(tdir)

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(tmpl_dir))
    for tmpl_name in ('user_data', 'meta_data.json'):
        template = env.get_or_select_template(tmpl_name)
        out = template.render(data)
        out_file = os.path.join(out_dir, tmpl_name)
        with open(out_file, 'w') as f:
            f.write(out)
        shutil.copy(out_file, alt_dir)

    return base_dir


def gen_iso(src, dst):
    subprocess.check_call(['genisoimage',
                           '-quiet',
                           '-input-charset', 'utf-8',
                           '-volid', 'config-2',
                           '-joliet',
                           '-rock',
                           '-output', '{}.tmp'.format(dst),
                           src])
    shutil.move('{}.tmp'.format(dst), dst)


def generate_cc(data, vm_name=None, tmpl_dir=TEMPLATE_DIR):
    data['ssh_authorized_keys'] = get_authorized_keys()
    data['my_name'] = vm_name
    data['my_uuid'] = uuid.uuid4()
    out_dir = render_and_save(data, vm_name=vm_name, tmpl_dir=tmpl_dir)
    conf_img = os.path.join(MY_DIR, '{}-config.iso'.format(vm_name))
    gen_iso(out_dir, conf_img)


def main():
    parser = optparse.OptionParser()
    parser.add_option('-c', '--ceph-release', dest='ceph_release',
                      help='ceph release to install')
    parser.add_option('-d', '--distro-release', dest='distro_release',
                      help='distro release codename (trusty, xenial)')
    parser.add_option('--callback-port', dest='host_web_callback_port',
                      type=int, default=8080,
                      help='VM phone home URL')
    parser.add_option('-t', '--template-dir', dest='tmpl_dir',
                      default=TEMPLATE_DIR,
                      help='config drive template dir')
    parser.add_option('--http-proxy', dest='http_proxy',
                      help='HTTP proxy for VMs')
    options, args = parser.parse_args()
    data = {
        'ceph_release': options.ceph_release,
        'distro_release': options.distro_release,
        'http_proxy': options.http_proxy,
        'host_name': 'sahost',
        'host_web_callback_port': options.host_web_callback_port,
    }
    for vm_name in args:
        generate_cc(data, vm_name=vm_name, tmpl_dir=options.tmpl_dir)


if __name__ == '__main__':
    main()
    sys.exit(0)
