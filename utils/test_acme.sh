#!/bin/bash

set -e
set -o pipefail
source /usr/local/share/helper_functions.sh
source $(dirname $BASH_SOURCE[0])/determine_cert_status

CHALLENGE_URI=.well-known/acme-challenge/test.txt
CHALLENGE_FILE=$CERTBOT_WEBROOT/$CHALLENGE_URI


mkdir -p $(dirname $CHALLENGE_FILE )
echo "$(date '+%F%T') test acme" > $CHALLENGE_FILE 


CHECK_FILE=$( tempfile /dev/shm/acmetest.XXXXXX )
curl -s http://localhost/$CHALLENGE_URI -o $CHECK_FILE

diff -q $CHALLENGE_FILE $CHECK_FILE 2>/dev/null 1>/dev/null \
    && export ACME_TEST_STATUS="passed"    \
    || export ACME_TEST_STATUS="failed"

rm -f $CHECK_FILE
rm -f $CHALLENGE_FILE
say "Local ACME test $ACME_TEST_STATUS"
if [ "$ACME_TEST_STATUS" = "passed" ]; then exit 0 ; else exit 1; fi
