#!/bin/bash

# it is a template
exec certbot renew ${CERTBOT_FLAGS} --post-hook reload_nginx $@
