#!/bin/bash

set -e
set -o pipefail

# these are potentially empty directories under single volume, which may 'disappear' if volume is bind-mounted
mkdir -p /mnt/data/letsencrypt/etc
mkdir -p /mnt/data/letsencrypt/lib
mkdir -p /mnt/data/letsencrypt/logs
mkdir -p /mnt/data/nginx_ssl
mkdir -p /mnt/data/watchers

mkdir -p $CERTBOT_WEBROOT

if [ ! -z "${NGINX_USER_UID}" ] ; then 
    usermod -u $NGINX_USER_UID nginx
fi 

mv /var/log/supervisor /tmp/supervisor_logs && ln -sf /tmp/supervisor_logs /var/log/supervisor 
echo '' > /var/run/docker_stderr 

if [ ! -z "$@" ]; then
    exec $@
else
    exec /bin/bash
fi
