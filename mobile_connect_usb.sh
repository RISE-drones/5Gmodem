#!/bin/bash

status="not_online"
device=/dev/cdc-wdm1
iface=wwan1
apn='5gsa02'

# set apn, requires boot to take effect!
sudo qmicli -d /dev/cdc-wdm1 --wds-modify-profile=3gpp,1,apn=$apn

echo "$device"
echo "Script setting for APN: $apn"
echo "Make sure reported APN is same as script setting"
qmicli -d /dev/cdc-wdm1 -p --wds-get-profile-list=3gpp
while [ "$status" != "online" ]
do
	sleep 2
	temp=$(qmicli -d $device --dms-get-operating-mode)
	echo "test"
	echo $temp
	cnt=$(printf '%s' "$temp" | grep "Mode: 'online'" -c)
	if [ $cnt -eq 1 ]; then
		status="online"
	else
		echo "Waiting for modem to report online"
	fi
done
echo "Modem reports online, try to connect"
# Put down interface to change locked settings
ifconfig $iface down
# Set expected dataformat to raw-ip
qmicli -d $device --set-expected-data-format='raw-ip'
# Take up interface
ifconfig $iface up
# Connect
qmicli -p -d $device --device-open-net='net-raw-ip|net-no-qos-header' --wds-start-network="apn=$apn,ip-type=4" --client-no-release-cid
# 1 Sec sleep for better robustness to 5g static ip
#sleep 1
# Start udhcpc for the interface, script fails if no lease (per design)
udhcpc -n -q -f -i $iface

# Add host route to specific host as required (RISE-drones use multiple modems and use routing)
# hostip=10.10.10.21
# echo 'Add route to hostip ('$hostip') stream via '$iface
# route add -host $hostip $iface

# Put monitoring on the connecion. System service will restart as soon as this scrips exits
pingok=0
attemts=5
echo "begin ping monitoring"
while [ $pingok -ne 1 ]; do
sleep 1
echo "send 5 pings to 10.10.10.21, if at least one is successful ping again"
# If no successful pings for 5-10s, break loop
# ping -Oc 5 8.8.8.8 > /dev/null && echo "up" || echo "down"
ping -Oc 5 -W 1 10.10.10.21 -I $iface > /dev/null && pingok=0 || pingok=1
done
echo "No successful ping for 5-10s, restart service"
