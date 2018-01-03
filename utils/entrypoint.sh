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

export CERT_NAME="${CERT_NAME:-default}"
export CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges
export CERTBOT_FLAGS="-n --cert-name $CERT_NAME"

if [ ! "$LE_PROD" = "true" ]; then
    CERTBOT_FLAGS="$CERTBOT_FLAGS --test-cert"
    say "Using staging LE endpoint. Explicitly set up LE_PROD=true to switch to production"
fi


mkdir -p $CERTBOT_WEBROOT

EXPECTED_CERTPATH=/etc/letsencrypt/live/$CERT_NAME
DOMAINS_LIST=""
for domain in $LE_DOMAINS ; do
    DOMAINS_LIST="$DOMAINS_LIST -d $domain"
done

if [ ! -e $EXPECTED_CERTPATH ]; then
    say "Provisioning certificates from letsencrypt"
    # generate temporary config without SSL support (as certs are absent yet), but with proxying for ACME challenges
    envsubst '$CERTBOT_WEBROOT $CERT_NAME' < /usr/share/nginx/ssl_params.template | grep -v ssl > /etc/nginx/ssl_params
    say "Running nginx in background"
    nginx
    certbot certonly $CERTBOT_FLAGS \
            --agree-tos -m $LE_EMAIL \
            --webroot -w $CERTBOT_WEBROOT \
            $DOMAINS_LIST
    # restore full config
    envsubst '$CERTBOT_WEBROOT $CERT_NAME' < /usr/share/nginx/ssl_params.template > /etc/nginx/ssl_params
else
    say "Trying to renew certificates"
    envsubst '$CERTBOT_WEBROOT $CERT_NAME' < /usr/share/nginx/ssl_params.template > /etc/nginx/ssl_params
    nginx
    certbot renew $CERTBOT_FLAGS 
fi

nginx -s stop

envsubst '$CERTBOT_FLAGS $CERT_NAME' < /opt/nginx-le/certbot_live_renew.sh > /usr/local/bin/certbot_live_renew
chmod u+x /usr/local/bin/certbot_live_renew

unset CERT_NAME EXPECTED_CERPATH DOMAIN_OPTS CERTBOT_WEBROOT LE_MAIL LE_DOMAINS

say "certbot is done"
say "now executing CMD: $@"
exec "$@"
