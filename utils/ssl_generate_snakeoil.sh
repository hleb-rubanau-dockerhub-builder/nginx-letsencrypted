#!/bin/bash

set -e 
set -o pipefail
source /usr/local/share/helper_functions.sh

require_vars SSL_CERTPATH
PRIMARY_DOMAIN=$1
shift
# reformat remaining arguments list into comma-separated with DNS: prefix
DOMAINS_LIST=$(echo "$*" | sed -e 's/ /,DNS:/g' -e 's/^/DNS:/' ) 
   
mkdir -p $SSL_CERTPATH
    
CERTKEY=$SSL_CERTPATH/privkey.pem
CERTPEM=$SSL_CERTPATH/fullchain.pem
   
# TODO: smarter logic to see if current cert is outdated or manages another set of domains
if [ ! -s $CERTKEY ] || [ ! -s $CERTPEM ] ; then
        say "Generating snakeoil certs at $SSL_CERTPATH"
        require_vars SNAKEOIL_COMPANY_DEPT SNAKEOIL_COMPANY_NAME SNAKEOIL_COMPANY_CITY SNAKEOIL_COMPANY_COUNTRY PRIMARY_DOMAIN
       
        
        CSRTEMPLATE=$(tempfile)
        cat > $CSRTEMPLATE <<CSR
[ req ]
prompt = no
default_bits = 2048
default_keyfile = privkey.pem
encrypt_key = no
distinguished_name = req_distinguished_name
 
string_mask = utf8only
 
req_extensions = v3_req,san

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ req_distinguished_name ]
OU=$SNAKEOIL_COMPANY_DEPT
O=$SNAKEOIL_COMPANY_NAME
L=$SNAKEOIL_COMPANY_CITY
C=$SNAKEOIL_COMPANY_COUNTRY
CN=$PRIMARY_DOMAIN

[san]
subjectAltName=$DOMAINS_LIST
CSR


       #say "DEBUG: contents of CSRTEMPLATE"
       #cat $CSRTEMPLATE

       openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $CERTKEY -out $CERTPEM -reqexts san -extensions san -config $CSRTEMPLATE

       rm $CSRTEMPLATE


    else
       say "Not provisioning snakeoil certs as they already exist"
    fi
       
    if [ ! -e $SSL_CERTPATH/chain.pem ]; then
        cd $SSL_CERTPATH ;
	    ln -sf fullchain.pem chain.pem
        cd -
    fi
