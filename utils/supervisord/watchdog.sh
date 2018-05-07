#!/bin/bash

source /usr/local/share/helper_functions.sh
source /usr/local/bin/supervisord/helper.sh


function read_and_parse_event() {
    read -r HEADER

    is_expected=""
    payload_length=""
    eventname=""
    if [ ! -z "$HEADER" ]; then
        for pair in $HEADER; do 
            if [ "${pair:0:9}" = "expected:" ]; then
                is_expected=$pair
            elif [ "${pair:0:4}" = "len:" ]; then
                payload_length=$( echo "$pair" | cut -f2 -d: )
            elif [ "${pair:0:10}"="eventname:" ]; then
                eventname="${pair:10}"
            fi
        done
    fi

    subject_process_name=""
    if [ ! -z "$payload_length" ]; then
        read -r -n $payload_length PAYLOAD 
        if [ ! -z "$PAYLOAD" ]; then
            for pair in $PAYLOAD; do
                if [ "${pair:0:12}" = "processname:" ]; then
                    subject_process_name="${pair:12}"
                elif [ "${pair:0:9}" = "expected:" ]; then
                    is_expected="${pair:9}"
                fi
            done
        fi
    fi

    subject_process_name=${subject_process_name:-unknown}
    if [ -z "$is_expected" ] && [ ! -z "$eventname" ] ; then
        if [ "$eventname" = "PROCESS_STATE_STOPPED" ]; then
            is_expected=1
        else
            is_expected=0
        fi
    fi

    is_expected=${is_expected:-0}

    if [ "$is_expected" = "1" ]; then 
        echo "expected:$subject_process_name" ; 
    else 
        echo "unexpected:$subject_process_name" ; 
    fi
}

procname_to_watch=$1 
require_var procname_to_watch
say_to_stderr "WATCHDOG: supervising $procname_to_watch"
report_status_ready

while true; do
    
    EVENT_STATUS=$( read_and_parse_event )
    IS_EXPECTED=$( echo "$EVENT_STATUS" | cut -f1 -d: )
    SUBJECT_PROCESS_NAME=$( echo "$EVENT_STATUS" | cut -f2- -d: )

    #say_to_stderr "WATCHDOG: payload=$PAYLOAD"
    if [ "$SUBJECT_PROCESS_NAME" != "$procname_to_watch" ]; then
        say_to_stderr "WATCHDOG: ignoring $IS_EXPECTED exit of $SUBJECT_PROCESS_NAME"
        report_event_result OKREADY
        continue
    fi

    say_to_stderr "WATCHDOG: process exit catched ($SUBJECT_PROCESS_NAME, $IS_EXPECTED )"
    say_to_stderr "WATCHDOG: going to kill container"

    for final_countdown in three two one ; do
        sleep 1;
    done

    supervisord_pid=$( cat /var/run/supervisord.pid )
    supervisord_pid=${supervisord_pid:-1}

    kill -s SIGQUIT $supervisord_pid 
    report_event_result OKREADY
done
