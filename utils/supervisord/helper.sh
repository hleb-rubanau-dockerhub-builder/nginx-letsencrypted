#!/bin/bash

function report_event_result() {
    case $1 in 
        OK)
            echo -n -e "RESULT 2\nOK\n"
            ;;
        OKREADY)
            echo -n -e "RESULT 2\nOKREADY\n"
            ;;
        FAIL)
            echo -n -e "RESULT 4\nFAIL\n"
            ;;
        FAILREADY)
            echo -n -e "RESULT 4\nFAILREADY\n"
            ;;
    esac
}

function report_status_ready(){
    perl -e 'select(STDOUT); $|=1; print STDOUT "READY\n";'; 
}


function say() {
    echo "[$(date '+%F %T')] $*" >>/var/run/docker_stderr
}

# clone function for the cases when previous one is overloaded
function say_to_stderr() {
    echo "[$(date '+%F %T')] $*" >>/var/run/docker_stderr
}
