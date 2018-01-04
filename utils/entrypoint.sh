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

    envsubst '$CERTBOT_WEBROOT $CERTBOT_FLAGS $SSL_CERTPATH $CERT_NAME' < $TEMPLATE_PATH
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


export CERT_MODE=${CERT_MODE:-staging}
export CERT_NAME="${CERT_NAME:-default}"
export CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges

say "CERT_MODE=$CERT_MODE"
if [ "$CERT_MODE" = 'snakeoil' ]; then
    export CERT_NAME='snakeoil'
    export SSL_CERTPATH=/etc/nginx/ssl/snakeoil
    echo "#!/bin/bash\necho 'Certificate renewal is not supported in snakeoil mode. Change CERT_MODE to use letsencrypt. Bye.';\n" > /usr/local/bin/certbot_live_renew

else

    export CERTBOT_FLAGS="-n --cert-name $CERT_NAME"

    if [ ! "$CERT_MODE" = "prod" ]; then
        say "Using staging LE endpoint. Explicitly set up CERT_MODE=prod to switch to production"
        export CERTBOT_FLAGS="$CERTBOT_FLAGS --test-cert"
    fi

    export SSL_CERTPATH=/etc/letsencrypt/live/$CERT_NAME
	
    mkdir -p $CERTBOT_WEBROOT
    render_template /opt/nginx-le/certbot_live_renew.sh > /usr/local/bin/certbot_live_renew

fi


chmod u+x /usr/local/bin/certbot_live_renew

mkdir -p /etc/nginx/ssl
if [ ! -e /etc/nginx/ssl/dhparam.pem ]; then
  say "dpharam is missing, generating it (may take time)"
  openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048 #4096
  say "dhparam generated"
else
  say "dhparam is already in place, not regenerating it"
fi

deploy_ssl_configs

if [ "$CERT_NAME" = "snakeoil" ]; then
    CERTKEY=$SSL_CERTPATH/privkey.pem
    CERTPEM=$SSL_CERTPATH/fullchain.pem

    mkdir -p $SSL_CERTPATH

    if [ ! -s $CERTKEY ] || [ ! -s $CERTPEM ] ; then
        say "Generating snakeoil certs at $SSL_CERTPATH"
       
        DOMAINS_LIST=$(echo "$LE_DOMAINS" | sed -e 's/ /,DNS:/g' -e 's/^/DNS:/' )
        PRIMARY_DOMAIN=$(echo "$LE_DOMAINS" | cut -f1 -d' ')
        
        CSRTEMPLATE=$(tempfile)
        cat > $CSRTEMPLATE <<CSR
[ req ]
prompt = no
default_bits = 2048
default_keyfile = privkey.pem
encrypt_key = no
distinguished_name = req_distinguished_name
 
string_mask = utf8only
 
req_extensions = v3_req,san

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ req_distinguished_name ]
OU=Self-Signed Certificates Department
O=SPECTRE
L=London
C=UK
CN=$PRIMARY_DOMAIN

[san]
subjectAltName=$DOMAINS_LIST
CSR


       say "DEBUG: contents of CSRTEMPLATE"
       cat $CSRTEMPLATE

       openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $CERTKEY -out $CERTPEM -reqexts san -extensions san -config $CSRTEMPLATE

       rm $CSRTEMPLATE

    else
       say "Not provisioning snakeoil certs"
    fi
else

    say "Provision/update letsencrypt certs ($CERT_MODE)"
	if [ ! -e $SSL_CERTPATH ]; then
	    enforce_webroot_only_mode 
	else 
	    enable_certs_mode
	fi
    
    DOMAINS_LIST=""
    for domain in $LE_DOMAINS ; do DOMAINS_LIST="$DOMAINS_LIST -d $domain" ; done

	say "Running nginx in background"
	nginx
	say "Calling certbot"
    
	certbot certonly $CERTBOT_FLAGS \
	    --agree-tos -m $LE_EMAIL \
	    --webroot -w $CERTBOT_WEBROOT \
	    $DOMAINS_LIST

	say "Stopping nginx"
	kill -TERM $(cat /var/run/nginx.pid) 
	#nginx -s stop
	while [ -f /var/run/nginx.pid ]; do
	  say "Waiting for nginx to shut down"
	  sleep 2;
	done

	say "Nginx stopped"

fi


say "Enabling certs mode and testing"	
enable_certs_mode
nginx -t

say "Clean up environment"
unset CERT_NAME SSL_CERTPATH DOMAIN_OPTS CERTBOT_WEBROOT LE_MAIL LE_DOMAINS

say "Entrypoint is over, passing execution to CMD ($@)"
exec "$@"
