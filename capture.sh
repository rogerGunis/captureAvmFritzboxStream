#!/bin/bash

# Exit on error. Append "|| true" if you expect an error.
#set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail

# -----------
# definitions
# -----------
TRAFFIC_PIPE="/tmp/traffic.cap"
source config

rm -f $TRAFFIC_PIPE

if [ ! -p $TRAFFIC_PIPE ];then
  mkfifo $TRAFFIC_PIPE
fi

CURL="curl -k -s"
WGET="wget --no-check-certificate -q"

# ---------------
# fetch challenge
# ---------------
CHALLENGE=$($CURL "${FBF}/login_sid.lua" | grep -Po '(?<=<Challenge>).*(?=</Challenge>)')

if [ -z $CHALLENGE ];then
    echo "Challange not found"
    exit;
fi

# -----
# login
# -----
MD5=$(echo -n ${CHALLENGE}"-"${PASS} | iconv -f ISO8859-1 -t UTF-16LE | md5sum -b | awk '{print substr($0,1,32)}')

if [ -z $MD5 ];then
    echo "MD5 not found"
    exit;
fi

RESPONSE="${CHALLENGE}-${MD5}"
SID=$($CURL -i -d "response=${RESPONSE}&username=${USER}" "${FBF}" | grep -Po -m 1 '(?<=sid=)[a-f\d]+'  | sort -u)

# $WGET -O- $FBF/cgi-bin/capture_notimeout?ifaceorminor=1-lan\&snaplen=\&capture=Start\&sid=$SID | /usr/bin/tshark -r -
$WGET -O$TRAFFIC_PIPE $FBF/cgi-bin/capture_notimeout?ifaceorminor=1-lan\&snaplen=\&capture=Start\&sid=$SID

