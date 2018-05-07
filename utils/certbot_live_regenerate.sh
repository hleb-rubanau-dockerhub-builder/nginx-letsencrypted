#!/bin/bash

set -e

echo "INVOKED: $0"
export CERT_MODE=${CERT_MODE:-staging}
LE_DOMAINS=$( $( dirname $0 )/get_domains_list.sh )
CERTBOT_FLAGS=$( $( dirname $0 )/get_certbot_flags.sh )

export CERT_NAME="${CERT_NAME:-default}"
export CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges
export SSL_CERTPATH=/etc/letsencrypt/live/$CERT_NAME

 
if [ "$CERT_MODE" = "snakeoil" ]; then
    echo "Snakeoil mode, doing nothing"
    exit;
fi

export CERTBOT_FLAGS="$CERTBOT_FLAGS --cert-name $CERT_NAME --expand "
    
DOMAINS_LIST=""
for domain in $LE_DOMAINS ; do DOMAINS_LIST="$DOMAINS_LIST -d $domain" ; done
	

set -x
certbot certonly $CERTBOT_FLAGS \
	    --agree-tos -m $LE_EMAIL \
	    --webroot -w $CERTBOT_WEBROOT \
	    $DOMAINS_LIST \
&& reload_nginx
