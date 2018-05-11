#!/bin/bash

set -e

source /usr/local/share/helper_functions.sh

# if failure was tracked during grace period
function letsencrypt_failed_recently() {
    [ -e $LETSENCRYPT_FAILURE_LOG_FILE ] && check_file_params $LETSENCRYPT_FAILURE_LOG_FILE -mmin -${LETSENCRYPT_FAILURE_GRACE_PERIOD}
}

function do_checks_and_configure_certmode() {
    # some early faiover checks
    if [ "$CERT_MODE" != "snakeoil" ]; then
        if [ ! -w /etc/letsencrypt ]; then
            say "WARNING: /etc/letsencrypt is likely mounted in RO mode, doing nothing with certs"
            LETSENCRYPT_NEEDS_FAILOVER="yes"
        elif [ -e $LETSENCRYPT_FAILURE_LOG_FILE ] && letsencrypt_failed_recently ; then
            say "WARNING: letsencrypt recently failed, doing nothing until grace period ($LETSENCRYPT_FAILURE_GRACE_PERIOD minutes) is over"
            LETSENCRYPT_NEEDS_FAILOVER="yes"
        elif [ -z "$LE_EMAIL" ]; then
            say "WARNING: letsencrypt mail is not configured"
            LETSENCRYPT_NEEDS_FAILOVER="yes"
        fi

        if [ "$LETSENCRYPT_NEEDS_FAILOVER" = "yes" ]; then
            if [ "$LETSENCRYPT_FAILOVER_TO_SNAKEOIL" = "yes" ] || [ "$LETSENCRYPT_FAILOVER_TO_SNAKEOIL" = "true" ]; then
                say "WARNING: temporary forcing snakeoil mode due to previous warnings"
                export CERT_MODE="snakeoil"
            fi 
        fi
    fi
}

require_var PRIMARY_DOMAIN

LE_DOMAINS="$( get_domains_list.sh )"
say "Full domains list [AUTOFILL_DOMAINS=${AUTOFILL_DOMAINS:-false}]: $LE_DOMAINS"

export CERT_MODE=${CERT_MODE:-staging}
source /usr/local/bin/determine_cert_paths

export CERT_NAME="${CERT_NAME:-default}"

do_checks_and_configure_certmode 
say "CERT_MODE=$CERT_MODE"


if [ "$CERT_MODE" = "snakeoil" ]; then
    provision_snakeoil_certs $PRIMARY_DOMAIN $LE_DOMAINS
elif [ "$LETSENCRYPT_NEEDS_FAILOVER" != "yes" ]; then
    provision_letsencrypt_certs $PRIMARY_DOMAIN $LE_DOMAINS

    say "Provision/update letsencrypt certs ($CERT_MODE)"
	if [ ! -e $SSL_CERTPATH ]; then
	    enforce_webroot_only_mode 
	else 
	    enable_certs_mode
	fi
    
    DOMAINS_LIST=""
    for domain in $LE_DOMAINS ; do DOMAINS_LIST="$DOMAINS_LIST -d $domain" ; done

    nginx -t || die "Nginx misconfiguration"
    say "Running nginx in background"
    nginx
    say "Calling certbot"
    
    certbot certonly $CERTBOT_FLAGS \
        --agree-tos -m $LE_EMAIL \
        --webroot -w $CERTBOT_WEBROOT \
        $DOMAINS_LIST   \
    || CERTBOT_FAILED="yes"

    if [ "$CERTBOT_FAILED" == "yes" ]; then
        msg="Generation failed for $LE_DOMAINS"
        say "ERROR: $msg"
        echo "[$(date +%F-%T)] FAILURE (mode=$CERT_MODE, domains: $LE_DOMAINS )" >> $LETSENCRYPT_FAILURE_LOG_FILE
    fi

	say "Stopping nginx"
	kill -TERM $(cat /var/run/nginx.pid) 
	#nginx -s stop
	while [ -f /var/run/nginx.pid ]; do
	  say "Waiting for nginx to shut down"
	  sleep 2;
	done

	say "Nginx stopped"
        

    if [ "$CERTBOT_FAILED" == "yes" ]; then maybe_failover_to_snakeoil ; fi

fi


say "Enabling certs mode and testing"	
enable_certs_mode
nginx -t

say "Clean up environment"
unset CERT_NAME SSL_CERTPATH DOMAIN_OPTS CERTBOT_WEBROOT LE_MAIL LE_DOMAINS \
      SNAKEOIL_COMPANY_DEPT SNAKEOIL_COMPANY_NAME SNAKEOIL_COMPANY_CITY SNAKEOIL_COMPANY_COUNTRY \
      LETSENCRYPT_FAILURE_GRACE_PERIOD LETSENCRYPT_FAILURE_LOG_FILE LETSENCRYPT_FAILOVER_TO_SNAKEOIL

set -x
say "Entrypoint is over, passing execution to CMD ($@)"
if [ "$@" = "nginx -g \"daemon off;\"" ]; then
    # for some reason interpolation of quotes did not work correctly
    say "Running nginx command explicitly"
    exec "nginx -g 'daemon off;'"
else
    say "Running CMD"
    exec $@
fi
