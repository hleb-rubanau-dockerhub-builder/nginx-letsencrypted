#!/bin/bash

CERTBOT_FLAGS="-n" 
if [ "$SSL_CERT_MODE" != "prod" ]; then
    CERTBOT_FLAGS="$CERTBOT_FLAGS --test-cert "
fi

# echo is not suitable for printing strings that start with dashes!
printf "%s\n" "$CERTBOT_FLAGS"
