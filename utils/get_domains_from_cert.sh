#! /bin/bash

source /usr/local/share/helper_functions.sh

certname=$1 
require_var certname 

for domain in $( openssl x509 -in $certname -text -noout | grep -A1 'Subject Alternative Name' | tail -n1 | sed -e 's/\, / /g' -e 's/DNS\://g' ); do echo $domain ; done | xargs echo
