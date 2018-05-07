#!/bin/bash

set -e

LE_DOMAINS=$( $( dirname $0 )/get_domains_list.sh )
CERTBOT_FLAGS=$( $( dirname $0 )/get_certbot_flags.sh )

source /usr/local/share/helper_functions.sh
source /usr/local/bin/determine_cert_paths


# --zero-tolerance flag is used to avoid tracking early exit as regeneration success
if [ "$SSL_CERT_MODE" = "snakeoil" ]; then
    echo "CERTBOT LIVE REGENERATE: Snakeoil mode, doing nothing"
    if [ "$1" = "--zero-tolerance" ]; then exit 1; else exit; fi
fi

if letsencrypt_failed_recently ; then
    say "CERTBOT LIVE REGENERATE: Letsencrypt failed recently, abstaining from any actions during grace period (${LETSENCRYPT_FAILURE_GRACE_PERIOD} minutes)";
    if [ "$1" = "--zero-tolerance"]; then exit 1; else exit ; fi
fi

export CERTBOT_FLAGS="$CERTBOT_FLAGS --cert-name $SSL_CERT_NAME --expand "
    
DOMAINS_LIST=""
for domain in $LE_DOMAINS ; do DOMAINS_LIST="$DOMAINS_LIST -d $domain" ; done
	

set -x
certbot certonly $CERTBOT_FLAGS \
	    --agree-tos -m $LE_EMAIL \
	    --webroot -w $CERTBOT_WEBROOT \
	    $DOMAINS_LIST 
