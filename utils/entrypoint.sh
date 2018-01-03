#!/bin/bash

set -e

function say() {
    echo "[$(date +%F-%T)] $*" >&2
}   

function die() {
    say "ERROR: $*"
    exit 1;
}

function require_var() {
    varname=$1
    if [ -z "${!varname}" ]; then
        die "Please define $varname"
    fi  
}

require_var LE_DOMAINS
require_var LE_EMAIL

CERTBOT_FLAGS="-n"

if [ ! "$LE_PROD" = "true" ]; then
    CERTBOT_FLAGS="$CERTBOT_FLAGS --test-cert"
    say "Using staging LE endpoint. Explicitly set up LE_PROD=true to switch to production"
fi

CERT_NAME="${CERT_NAME:-default}"
CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges

mkdir -p $CERTBOT_WEBROOT

EXPECTED_CERTPATH=/etc/letsencrypt/live/$CERT_NAME
DOMAINS_LIST=""
for domain in $LE_DOMAINS ; do
    DOMAINS_LIST="$DOMAIN_LIST -d $domain"
done

say "Running nginx in background"
envsubst '$CERTBOT_WEBROOT $CERT_NAME' < /usr/share/nginx/ssl_params.template > /etc/nginx/ssl_params
envsubst '$CERT_NAME' < /opt/utils/certbot_live_renew.sh > /usr/local/bin/certbot_live_renew
nginx 

if [ ! -e $EXPECTED_CERTPATH ]; then
    say "Provisioning certificates from letsencrypt"
    certbot certonly $CERTBOT_FLAGS \
            --agree-tos -m $LE_EMAIL \
            --webroot -w $CERTBOT_WEBROOT \
            --cert-name $CERT_NAME        \
            $DOMAINS_LIST
else
    say "Trying to renew certificates"
    certbot renew $CERTBOT_FLAGS --cert-name $CERT_NAME 
fi

nginx -s stop

chmod u+x /usr/local/bin/certbot_live_renew

unset CERT_NAME EXPECTED_CERPATH DOMAIN_OPTS CERTBOT_WEBROOT LE_MAIL LE_DOMAINS

say "certbot is done"

exec $@
