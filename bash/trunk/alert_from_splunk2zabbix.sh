#!/bin/bash
# script will send send data from a saved search to 
# zabbix master

ZABBIXHOST=sysmon-1.rz2012.adm.denic.de
ZABBIXPORT=10051

SERVICE=`echo $4|awk -F' - ' '{print $2}'`
HOST=`echo $4|awk -F' - ' '{print $1}'`
EVENTS=$1
SEARCH=$2
LINK=$6

function send_msg {
	# host, key, value
	/usr/bin/zabbix_sender -z $ZABBIXHOST -p $ZABBIXPORT -s $1 -k $2 -o "$msg"
}


msg="$SEARCH -- $EVENTS -- $LINK"

send_msg $HOST $SERVICE
