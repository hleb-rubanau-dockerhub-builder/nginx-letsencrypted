#!/bin/bash

set -e

echo "INVOKED: $0"
export CERT_MODE=${CERT_MODE:-staging}
LE_DOMAINS=$( $( dirname $0 )/get_domains_list.sh )
CERTBOT_FLAGS=$( $( dirname $0 )/get_certbot_flags.sh )

export CERT_NAME="${CERT_NAME:-default}"
export CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges
export SSL_CERTPATH=/etc/letsencrypt/live/$CERT_NAME

# if failure was tracked during grace period
function letsencrypt_failed_recently() {
    check_file_params $LETSENCRYPT_FAILURE_LOG_FILE -mmin -${LETSENCRYPT_FAILURE_GRACE_PERIOD}
}
 
if [ "$CERT_MODE" = "snakeoil" ]; then
    echo "Snakeoil mode, doing nothing"
    exit;
elif [ -e $LETSENCRYPT_FAILURE_LOG_FILE ] || letsencrypt_failed_recently ; then
    echo "Letsencrypt failed recently, abstaining from any actions during grace period (${LETSENCRYPT_FAILURE_GRACE_PERIOD} minutes)";
    exit 1;
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
