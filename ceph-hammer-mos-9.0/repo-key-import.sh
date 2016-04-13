#!/bin/sh
set -e
cd "${0%/*}"
umask 022
wget -N http://mirror.fuel-infra.org/mos-repos/ubuntu/9.0/archive-mos9.0.key
mkdir -p -m 700 gnupg
exec gpg --homedir `pwd`/gnupg --import  archive-mos9.0.key
