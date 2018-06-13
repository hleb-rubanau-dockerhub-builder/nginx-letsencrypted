#!/bin/bash

source /usr/local/share/helper_functions.sh
source /usr/local/bin/supervisord/helper.sh

report_status_ready
while true; do
    read HEADER
    METRICS_LINE=$( get_nginx_metrics )
    if [ ! -z "$METRICS_LINE" ]; then
        say "$METRICS_LINE" 
    fi    
    report_event_result OKREADY
done
