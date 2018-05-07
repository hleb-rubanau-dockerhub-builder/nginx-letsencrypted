#!/bin/bash

set -e

nginx -t && nginx -s reload \
    && nginx_config_md5 > $NGINX_CONF_WATCHER_LOG
