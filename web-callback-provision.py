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
    g = web.storage({'all_vms': vms_to_wait,
                     'seen_vms': set([]),
                     'app': app})

    def _wrapper(handler):
        web.ctx.globals = g
        return handler()
    return _wrapper


class VMRegister(object):

    def POST(self):
        web_input = web.input()
        hostname = web_input.hostname
        pubkey = web_input.pub_key_rsa.strip()
        all_vms = web.ctx.globals.all_vms
        seen_vms = web.ctx.globals.seen_vms
        print("VM '{0}' ready, ssh public key '{1}'".format(hostname, pubkey))
        seen_vms.add(hostname)
        update_known_hosts(hostname=hostname, ssh_key=pubkey)
        if all_vms and all_vms.issubset(seen_vms):
            # XXX: way too cowboy-style
            web.ctx.globals.app.stop()


def main():
    parser = OptionParser()
    parser.add_option('-m', dest='all_vms',
                      help='exit after specified VMs have been provisioned')
    options, args = parser.parse_args()
    all_vms = set([])
    if options.all_vms:
        all_vms = set(options.all_vms.split(','))

    # web.py needs this
    sys.argv = args
    app = web.application(urls, globals())
    app.add_processor(add_state_hook(all_vms, app))
    app.run()


if __name__ == '__main__':
    main()
