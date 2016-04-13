#!/bin/sh
cd "${0%/*}"
export GNUPGHOME=`pwd`/gnupg
if [ ! -d "$GNUPGHOME" ]; then
	./repo-key-import.sh
fi
# NB: --noskipold tells reprepro to refresh filters, it has nothing to do
# with re-downloading already available versions of packages.
exec reprepro -Vb. --restrict ceph --restrict ceph-deploy --noskipold update
