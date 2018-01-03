#!/bin/bash

set -e

CONFIG_ENDPOINTS="ssl_params ssl_default_server_params"

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

function render_template() {
    TEMPLATE_PATH=$1 
    if [ -z "$TEMPLATE_PATH" ]; then die "Template name not provided" ; fi
    if [ ! -e "$TEMPLATE_PATH" ]; then die "Template not found: $TEMPLATE_PATH" ; fi

    envsubst '$CERTBOT_WEBROOT $CERTBOT_FLAGS $CERT_NAME' < $TEMPLATE_PATH
}

function path_to_ssl_disabled_config() {
    echo /etc/nginx/ssl_disabled_$1
}

function path_to_ssl_enabled_config() {
    echo /etc/nginx/ssl_enabled_$1
}

function deploy_ssl_configs() {
    for template in /usr/share/nginx/nginx_params/* ; do
	tname=$(basename $template)
        destpath=/etc/nginx/$tname
        say "Rendering $template -> $destpath"
	    # to ensure there's no remaining links
	    rm -f $destpath 
        render_template $template > $destpath
    done

    for config_endpoint in $CONFIG_ENDPOINTS ; do
       mv /etc/nginx/$config_endpoint $( path_to_ssl_enabled_config $config_endpoint )
       ln -sf /etc/nginx/acme_webroot_params $( path_to_ssl_disabled_config $config_endpoint )
    done
}

function enable_certs_mode() {
    for config_endpoint in $CONFIG_ENDPOINTS ; do
      ln -sfv $( path_to_ssl_enabled_config $config_endpoint )  /etc/nginx/$config_endpoint 
    done
}

function enforce_webroot_only_mode() {
    for config_endpoint in $CONFIG_ENDPOINTS ; do
      ln -sfv $( path_to_ssl_disabled_config $config_endpoint ) /etc/nginx/$config_endpoint 
    done
}

require_var LE_DOMAINS
require_var LE_EMAIL

DOMAINS_LIST=""
for domain in $LE_DOMAINS ; do
    DOMAINS_LIST="$DOMAINS_LIST -d $domain"
done

export CERT_NAME="${CERT_NAME:-default}"
export CERTBOT_FLAGS="-n --cert-name $CERT_NAME"

if [ ! "$LE_PROD" = "true" ]; then
    export CERTBOT_FLAGS="$CERTBOT_FLAGS --test-cert"
    say "Using staging LE endpoint. Explicitly set up LE_PROD=true to switch to production"
fi

export CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges

mkdir -p $CERTBOT_WEBROOT
render_template /opt/nginx-le/certbot_live_renew.sh > /usr/local/bin/certbot_live_renew
chmod u+x /usr/local/bin/certbot_live_renew


deploy_ssl_configs
EXPECTED_CERTPATH=/etc/letsencrypt/live/$CERT_NAME

if [ ! -e $EXPECTED_CERTPATH ]; then
    enforce_webroot_only_mode 
else 
    enable_certs_mode
fi

say "Running nginx in background"
nginx
say "Calling certbot"
certbot certonly $CERTBOT_FLAGS \
    --agree-tos -m $LE_EMAIL \
    --webroot -w $CERTBOT_WEBROOT \
    $DOMAINS_LIST

say "Stopping nginx"
nginx -s stop

enable_certs_mode
nginx -t

say "Clean up environment"
unset CERT_NAME EXPECTED_CERPATH DOMAIN_OPTS CERTBOT_WEBROOT LE_MAIL LE_DOMAINS

say "Entrypoint is over, passing execution to CMD ($@)"
exec "$@"
