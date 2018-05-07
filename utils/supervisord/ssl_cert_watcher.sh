#!/bin/bash

source /usr/local/share/helper_functions.sh
source /usr/local/bin/supervisord/helper.sh
source /usr/local/bin/determine_cert_paths

# this script just tracks domain ist updates so that SSL watcher may make decisions and enforce grace period
NGINX_DOMAINS_WATCHER_LOG=/var/log/watchers/nginx_domains_watcher.log

# if domains check was performed more than 5 minutes ago
function domains_stabilized() {
    check_file_params $NGINX_DOMAINS_WATCHER_LOG -mmin +5
}

function calculate_difference() {
    perl -e 'my @old=qw/'"$actual_domains_list"'/; my @new=qw/'"$configured_domains_list"'/; my %oldhash=map { $_ => 1 } @old; for (@new) { print "$_\n" unless $oldhash{$_} ; } '
}

function say_and_track() {
    echo "[$(date '+%F %T')] $*" | tee -a $CERTS_UPDATER_LOG 1>>/var/run/docker_stderr 2>>/var/run/docker_stderr
}


function regenerate_snakeoil_certs() {
    REGEN_CMD="provision_snakeoil_certs $*"

    say_and_track "Regenerating snakeoil certs" \
    && ( $REGEN_CMD 2>>/var/run/docker_stderr 1>>/var/run/docker_stderr )  \
    && say_to_stderr "Snakeoil certs regenerated, they'll be picked up by nginx soon"               \
    || say_to_stderr "Snakeoil certs regeneration/reload FAILED"
}

# runs update script plus leaves traces of activity around, and redirects output correctly
function update_letsencrypt_certs() {

    if [ "$1" = "generate" ]; then
        # we need zero-tolerance flag to avoid considering early exit as a success
        # normally, this whole function should not be called when there's recent letsencrypt failure or ongoing concurrent cert update
        REGEN_CMD='certbot_live_regenerate.sh --zero-tolerance'
        OPNAME='regeneration'
    else
        REGEN_CMD='certbot_live_renew.sh'
        OPNAME='renewal'
    fi 

    if letsencrypt_failed_recently ; then
        say_to_stderr "WARNING: skipping letsencrypt $OPNAME due to recent errors (grace period is $LETSENCRYPT_FAILURE_GRACE_PERIOD minutes)"
    else
        unset REGEN_FAILED
        ( $REGEN_CMD 2>>/var/run/docker_stderr 1>>/var/run/docker_stderr ) || REGEN_FAILED="true"

        # just process results
        if [ "$REGEN_FAILED" = "true" ]; then
            msg="LETSENCRYPT ERROR: $OPNAME failed (mode: $SSL_CERT_MODE, domains: $configured_domains_list )" 
            say_and_track $msg
            echo "[$(date '+%F %T')] $msg" >> $LETSENCRYPT_FAILURE_LOG_FILE
        else    
            say_and_track "LETSENCRYPT: $OPNAME successful (mode: $SSL_CERT_MODE, domains: $configured_domains_list )" 
        fi
    fi               
}


report_status_ready
while true; do
    read HEADER

    if ( domains_stabilized && no_concurrent_cert_update ); then
        actual_domains_list=$( get_domains_from_cert.sh $SSL_CERT_PEMFILE )
        configured_domains_list=$( get_domains_list.sh  )
        difference=$( calculate_difference | xargs echo )

        source /usr/local/bin/determine_cert_status

        if [ ! -z "$difference" ] && no_concurrent_cert_update ; then
            #say_to_stderr "SSL: actual_domains_list     =$actual_domains_list"
            #say_to_stderr "SSL: configured_domains_list =$configured_domains_list"
            #say_to_stderr "SSL: domains not in cert: $difference"
            
            # establish soft lock
            say_and_track "Adding $difference to cert $SSL_CERT_PEMFILE"

            if [ "$SSL_CERT_MODE" = "snakeoil" ]; then
                regenerate_snakeoil_certs $PRIMARY_DOMAIN $configured_domains_list
            else
                update_letsencrypt_certs generate
            fi 
        elif [ "$SSL_CERT_STATUS" = "outdated" ] && no_concurrent_cert_update ; then
            say_and_track "WARNING: SSL certificate is outdated, renewal required"
            if [ "$SSL_CERT_MODE" = "snakeoil" ] ; then
                regenerate_snakeoil_certs $PRIMARY_DOMAIN $configured_domains_list
            else
                update_letsencrypt_certs renew
            fi
        fi  
    else 
        bypass_reason="domains are not stabilized yet and/or concurrent cert update is happening"
        if domains_stabilized ; then
          bypass_reason="concurrent cert update is happening"
        elif no_concurrent_cert_update ; then
          bypass_reason="domains are not stabilized yet"
        fi
        say_to_stderr "SSL WATCHER: skip operations, as $bypass_reason"
    fi

    report_event_result OKREADY

done
