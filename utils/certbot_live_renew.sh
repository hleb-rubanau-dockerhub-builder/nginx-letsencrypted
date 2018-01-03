#!/bin/bash

exec certbot renew ${CERTBOT_FLAGS} --post-hook reload_nginx $@
