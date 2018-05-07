#!/bin/bash

set -e
source /usr/local/share/helper_functions.sh

CERT_MODE=${CERT_MODE:-staging}

# prints to stdouts and exits successfuly
function result() { echo $* ; exit }

if [ "$CERT_MODE" = "snakeoil" ]; then print_and_exit $CERT_MODE ; fi

export CERT_MODE
# anything else is letsencrypt


if [ "$CERT_MODE" = "letsencrypt_readonly" ]; then
fi
