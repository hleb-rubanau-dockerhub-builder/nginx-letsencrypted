#!/bin/bash

set -e

source /usr/local/share/helper_functions.sh

ORIGINAL_CMD=$0 
ORIGINAL_PARAMS=$1

function failover_to_snakeoil() {
    nginx_shutdown.sh # always succeeds and is kind of silent
    export SSL_CERT_MODE="snakeoil"
    unset SSL_CERT_ACCEPTED_STRATEGY
    exec $ORIGINAL_CMD $ORIGINAL_PARAMS 
}

function check_init_results() {
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
            failover_to_snakeoil
        else
            die "Certificates are missing, and cannot be generated, and there are no failover strategies left. Giving up."
        fi
    fi
}



function on_letsencrypt_generation_failure() {
    # failure is already tracked by underlying script
    if [ "$SSL_TRY_TO_FAILOVER_ON_ERRORS" ]; then
        source /usr/local/bin/determine_cert_status
        if [ "$SSL_CERT_STATUS" != "missing" ] && [ "$SSL_CERT_MODE" != "snakeoil" ]; then
            say "WARNING: some errors occured during letsencrypt generation; however, we will proceed"
        else
            say "WARNING: some errors happened during letsencrypt generation, and cert file(s) are missing -- switching to snakeoil mode"
            failover_to_snakeoil
        fi
    fi
}


require_var PRIMARY_DOMAIN

DESIRED_DOMAINS_LIST="$( get_domains_list.sh )"
say "Full domains list [AUTOFILL_DOMAINS=${AUTOFILL_DOMAINS:-false}]: $DESIRED_DOMAINS_LIST"

export SSL_CERT_MODE=${SSL_CERT_MODE:-staging}
source /usr/local/bin/determine_cert_strategy


check_init_results

provision_renewal_script $SSL_CERT_MODE

if [ "$SSL_CERT_MODE" = "snakeoil" ]; then
    tweak_nginx_configs force_snakeoil_mode 
else
    tweak_nginx_configs force_letsencrypt_mode
fi 

if [ "$SSL_CERT_DESIRED_STRATEGY" = "generate" ] || [ "$SSL_CERT_DESIRED_STRATEGY" = "renew" ]; then
    if [ "$SSL_CERT_MODE" = "snakeoil" ]; then
        provision_snakeoil_certs $PRIMARY_DOMAIN $DESIRED_DOMAINS_LIST
    else
        provision_letsencrypt_certs $PRIMARY_DOMAIN $DESIRED_DOMAINS_LIST  || on_letsencrypt_generation_failure 
    fi
fi

nginx -t || die "Nginx configuration check failed"
nginx_config_md5 > $NGINX_CONF_WATCHER_LOG

# clean up old log to prevent it's growth
#rm -f $WATCHERS_STATE_DIR/supervisor_logs/supervisord.log

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
