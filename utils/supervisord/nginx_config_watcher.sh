#!/bin/bash

NGINX_CONF_WATCHER_LOG=/var/run/nginx_conf_watcher.log
source /usr/local/bin/supervisord/helper.sh

function trigger_reload() {
    reload_nginx 1>>/var/run/docker_stderr 2>>/var/run/docker_stderr 
}

report_status_ready
while true; do
    read HEADER

    last_config_md5=$( ( tail -n1 $NGINX_CONF_WATCHER_LOG || true ) | cut -f2 -d@ )
    config_md5="$( nginx_config_md5 | cut -f2 -d@ )"
    if [ "$last_config_md5" != "$config_md5" ]; then
        say "NGINX CONFIG CHANGE detected, trying to reload" 
        #say "DEBUG: last_config_md5=$last_config_md5"
        #say "DEBUG: config_md5=$config_md5"

        trigger_reload || say "NGINX RELOAD FAILED" 
    fi

    report_event_result OKREADY
done
