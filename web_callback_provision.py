#!/usr/bin/env python
# coding: utf-8
# Purpose: receives provisioned VMs info via cloud-init phone_home

import sys
import web
from optparse import OptionParser
from virtutils import update_known_hosts


urls = (
    '/', 'VMRegister'
)


def add_state_hook(vms_to_wait, app):
    g = web.storage({'all_vms': set(vms_to_wait),
                     'vm_ssh_keys': dict(),
                     'app': app})

    def _wrapper(handler):
        web.ctx.globals = g
        return handler()
    return _wrapper


class VMRegister(object):

    def POST(self):
        web_input = web.input()
        vm_name = web_input.hostname
        pubkey = web_input.pub_key_rsa.strip()
        all_vms = web.ctx.globals.all_vms
        vm_ssh_keys = web.ctx.globals.vm_ssh_keys
        vm_ssh_keys[vm_name] = pubkey
        seen_vms = set(vm_ssh_keys.keys())
        if all_vms and all_vms.issubset(seen_vms):
            for vm_name, ssh_key in vm_ssh_keys.iteritems():
                print("{vm_name} {ssh_key}".format(vm_name=vm_name,
                                                   ssh_key=ssh_key))
                update_known_hosts(vm_name=vm_name, ssh_key=ssh_key)
            # XXX: way too cowboy-style
            web.ctx.globals.app.stop()


def run_web_callback(httpd_args, vms2wait=None):
    if not vms2wait:
        vms2wait = set([])
    # web.py has no sensible API to pass IP to bind
    new_argv = [sys.argv[0]]
    new_argv.extend(httpd_args)
    sys.argv = new_argv
    app = web.application(urls, globals())
    app.add_processor(add_state_hook(vms2wait, app))
    app.run()


def main():
    parser = OptionParser()
    parser.add_option('-l', '--listen', dest='listen',
                      default='0.0.0.0:8080',
                      help='interface/address to listen at')
    options, args = parser.parse_args()
    run_web_callback([options.listen], vms2wait=args)


if __name__ == '__main__':
    main()
