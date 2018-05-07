#!/bin/bash

# it is a template
#exec certbot renew ${CERTBOT_FLAGS} --allow-subset-of-names --post-hook reload_nginx $@
## we do not run 'reload nginx' as in live mode changes will be picked up by config watcher
exec certbot renew ${CERTBOT_FLAGS} --allow-subset-of-names  $@
