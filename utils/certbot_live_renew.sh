#!/bin/bash

# it is a template
exec certbot renew ${CERTBOT_FLAGS} --allow-subset-of-names --post-hook reload_nginx $@
