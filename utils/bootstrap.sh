#!/bin/bash

set -e

source /usr/local/share/helper_functions.sh

require_var PRIMARY_DOMAIN

DESIRED_DOMAINS_LIST="$( get_domains_list.sh )"
say "Full domains list [AUTOFILL_DOMAINS=${AUTOFILL_DOMAINS:-false}]: $LE_DOMAINS"

export SSL_CERT_MODE=${SSL_CERT_MODE:-staging}
source /usr/local/bin/determine_cert_strategy

report_ssl_cert_strategy

if [ "$SSL_CERT_ACCEPTED_STRATEGY" = "fail" ]; then
    if [ "$SSL_TRY_TO_FAILOVER_ON_ERRORS" != "true" ]; then    
        die "Cannot proceed with $SSL_CERT_DESIRED_STRATEGY"
    fi
    
    # attempts to failover
        
    # if SOME certs are in place, just use them
    if [ "$SSL_CERT_STATUS" != "missing" ]; then
        say "WARNING: some errors found. Proceeding with existing certificates, not applying action '"$SSL_CERT_DESIRED_STRATEGY"'"
        export SSL_CERT_ACCEPTED_STRATEGY="proceed"
    elif [ "$SSL_CERT_MODE" != "snakeoil" ]; then
        say "WARNING: certificates are missing, and letsencrypt cannot proceed. Trying snakeoil failover"
        export SSL_CERT_MODE="snakeoil"
        exec $0 $*
    else
        die "Certificates are missing, and cannot be generated, and there are no failover strategies left. Giving up."
    fi
fi

provision_renewal_script $SSL_CERT_MODE

if [ "$SSL_CERT_MODE" = "snakeoil" ]; then
    tweak_nginx_configs force_snakeoil_mode 
else
    tweak_nginx_configs force_letsencrypt_mode
fi 

if [ "$SSL_CERT_DESIRED_STRATEGY" = "generate" ] || [ "$SSL_CERT_DESIRED_STRATEGY" = "renew" ]; then
    if [ "$CERT_MODE" = "snakeoil" ]; then
        provision_snakeoil_certs $PRIMARY_DOMAIN $LE_DOMAINS
    else
        provision_letsencrypt_certs $PRIMARY_DOMAIN $LE_DOMAINS || LE_FAILURE="true"
        if [ "$LE_FAILURE"  = "true" ] ; then
            if [ "$SSL_TRY_TO_FAILOVER_ON_ERRORS" ]; then
                source /usr/local/bin/determine_cert_status
                if [ "$SSL_CERT_STATUS" != "missing" ]; then
                    say "WARNING: some errors occured during letsencrypt generation; however, we will proceed"
                else
                    say "WARNING: some errors happened during letsencrypt generation, and cert file(s) are missing -- switching to snakeoil mode"
                    export SSL_CERT_MODE=snakeoil
                    exec $0 $*
                fi
            fi
        fi
    fi
fi


exec /usr/bin/supervisord -n -c /etc/supervisord.conf
