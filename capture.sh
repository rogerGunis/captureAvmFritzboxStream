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
if [ $? != 0 ];then
   echo "pipe $TRAFFIC_PIPE not removeable"
   exit 1;
fi

if [ ! -p $TRAFFIC_PIPE ];then
  mkfifo $TRAFFIC_PIPE
fi

CURL="curl -k -s"
WGET="wget --no-check-certificate -q -t 0 --timeout=60 --waitretry=300"

# ---------------
# fetch challenge
# ---------------
function get_session_id() {
	CHALLENGE=$($CURL "${FBF}/login_sid.lua" | grep -Po '(?<=<Challenge>).*(?=</Challenge>)')

	if [ -z $CHALLENGE ];then
		echo "Challange not found"
		exit 1;
	fi

# -----
# login
# -----
	MD5=$(echo -n ${CHALLENGE}"-"${PASSWORD} | iconv -f ISO8859-1 -t UTF-16LE | md5sum -b | awk '{print substr($0,1,32)}')

	if [ -z $MD5 ];then
		echo "MD5 not found"
		exit;
	fi

	RESPONSE="${CHALLENGE}-${MD5}"
	SID=$($CURL -i -d "response=${RESPONSE}&username=${USER}" "${FBF}" | grep -Po -m 1 '(?<=sid=)[a-f\d]+'  | sort -u)
    echo $SID
}

if [ -z "${PASSWORD}" ];then
   echo -n "Enter your router password: "; read PASSWORD;
fi
SID=$(get_session_id)
if [ -z "$SID" -o "$SID" == "0000000000000000" ]; then
    echo "Authentication failure!"
    exit
fi

MODE=${1:-}
IFACE=""
if [ -z "$MODE" ];then
	echo ""
	echo "What do you want to capture?"
	echo "INTERNET:"
	echo "   1) Internet"
	echo "   2) Interface 0"
	echo "   3) Routing Interface"
	echo "INTERFACES:"
	echo "   4) tunl0"
	echo "   5) eth0"
	echo "   6) eth1"
	echo "   7) eth2"
	echo "   8) eth3"
	echo "   9) lan"
	echo "  10) hotspot"
	echo "  11) wifi0"
	echo "  12) ath0"
	echo "WIFI:"
	echo "  13) AP 2.4 + 5 GHz wifi1"
	echo "  14) AP 2.4 + 5 GHz wifi0"
	echo "  15) WLAN Management Traffic"
	echo ""
fi

while true; do 
if [ -z "$MODE" ];then
    echo -n "Enter your choice [0-15] ('q' for quit): "; read MODE;
fi
    if (("$MODE" > "0")) && (("$MODE" < "16")); then
        if [ "$MODE" == "1" ]; then
            IFACE="2-1"
        elif [ "$MODE" == "2" ]; then
            IFACE="3-17"
        elif [ "$MODE" == "3" ]; then
            IFACE="3-0"
        elif [ "$MODE" == "4" ]; then
            IFACE="1-tunl0"
        elif [ "$MODE" == "5" ]; then
            IFACE="1-eth0"
        elif [ "$MODE" == "6" ]; then
            IFACE="1-eth1"
        elif [ "$MODE" == "7" ]; then
            IFACE="1-eth2"
        elif [ "$MODE" == "8" ]; then
            IFACE="1-eth3"
        elif [ "$MODE" == "9" ]; then
            IFACE="1-lan"
        elif [ "$MODE" == "10" ]; then
            IFACE="1-hotspot"
        elif [ "$MODE" == "11" ]; then
            IFACE="1-wifi0"
        elif [ "$MODE" == "12" ]; then
            IFACE="1-ath0"
        elif [ "$MODE" == "13" ]; then
            IFACE="4-131"
        elif [ "$MODE" == "14" ]; then
            IFACE="4-130"
        elif [ "$MODE" == "15" ]; then
            IFACE="4-128"
        fi
        break
    elif [ "$MODE" == "q" ]; then
        exit
    fi
done

if [ -z "${IFACE}" ];then
	echo "No interface selected"
	exit 1;
fi

# $WGET -O- $FBF/cgi-bin/capture_notimeout?ifaceorminor=$IFACE\&snaplen=\&capture=Start\&sid=$SID | /usr/bin/tshark -r - $TSHARK_FILTER 

$WGET -O$TRAFFIC_PIPE $FBF/cgi-bin/capture_notimeout?ifaceorminor=${IFACE}\&snaplen=\&capture=Start\&sid=$SID &
sudo nprobe --as-list /usr/share/GeoIP/GeoIPASNum.dat --city-list /usr/share/GeoIP/GeoIPCity.dat  -V 10 -i /tmp/traffic.cap -q ${SOURCE_IP}:9995 -a -n ${TARGET_IP}:9995 -w 2097152 -t 60 -Q 0 -u 0 -E 1:3 -p 1/1/1/1/1/1 -O 1 -g /tmp/nprobe.traffic.pid -b 2 # --debug
