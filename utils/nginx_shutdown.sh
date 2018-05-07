#!/bin/bash

source /usr/local/share/helper_functions.sh

say "NGINX: force stop"
nginx -s stop 2>/dev/null 1>/dev/null \
    && say "NGINX: stopped"  \
    || true
