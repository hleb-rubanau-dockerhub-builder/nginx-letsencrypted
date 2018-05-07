#!/bin/bash

# this script just tracks domain ist updates so that SSL watcher may make decisions and enforce grace period
NGINX_DOMAINS_WATCHER_LOG=$WATCHERS_STATE_DIR/nginx_domains_watcher.log
source /usr/local/bin/supervisord/helper.sh

report_status_ready
while true; do
    # we actually ignore header
    read -r HEADER

    last_domains_list="$( (tail -n1 $NGINX_DOMAINS_WATCHER_LOG 2>>/var/run/docker_stderr || true ) | cut -f2 -d@ | sed -r -e 's/^\s//g' )"
    current_domains_list="$( get_domains_list.sh 2>>/var/run/docker_stderr )"

    if [ "$last_domains_list" != "$current_domains_list" ]; then
        say "DOMAINS LIST CHANGED FROM: $last_domains_list" 
        say "DOMAINS LIST CHANGED TO:   $current_domains_list" 
        echo "$(date +%F_%H%M%S ) @ $current_domains_list" >> $NGINX_DOMAINS_WATCHER_LOG 
    fi
    
    report_event_result OKREADY
done
