#!/bin/bash

exec certbot renew --post-hook reload_nginx --cert-name ${CERT_NAME} -n
