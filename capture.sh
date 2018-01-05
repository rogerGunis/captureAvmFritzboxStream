#!/bin/bash
# -----------
# definitions
# -----------
FBF="https://<IP>:<PORT>"
USER=""
PASS=""

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

$WGET -O- $FBF/cgi-bin/capture_notimeout?ifaceorminor=1-lan\&snaplen=\&capture=Start\&sid=$SID | /usr/bin/tshark -r -

