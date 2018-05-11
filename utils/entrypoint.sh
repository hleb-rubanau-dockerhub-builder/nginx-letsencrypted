#!/bin/bash

set -e
set -o pipefail

# these are potentially empty directories under single volume, which may 'disappear' if volume is bind-mounted
mkdir -p /mnt/data/letsencrypt/etc
mkdir -p /mnt/data/letsencrypt/lib
mkdir -p /mnt/data/letsencrypt/logs
mkdir -p /mnt/data/nginx_ssl
mkdir -p /mnt/data/logs

if [ ! -z "$@" ]; then
    exec $@
else
    exec /bin/bash
fi
