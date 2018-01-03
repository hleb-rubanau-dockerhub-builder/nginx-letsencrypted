#!/bin/bash

kill -HUP $(cat /var/run/nginx.pid)
