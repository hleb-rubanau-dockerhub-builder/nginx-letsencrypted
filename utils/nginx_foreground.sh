#!/bin/bash

# just a wrapper to be used in scripts and avoid quotation issues with 'daemon off' part
exec nginx -g 'daemon off;'
