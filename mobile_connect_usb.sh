#!/bin/bash

status="not_online"
apn='5gsa02.static'
hostip=10.10.10.21

# Find where 5Gmodem is connected. set device and interface. We assume the modem is connected to wdm0 or wdm1!
sudo qmicli -d /dev/cdc-wdm0 --dms-get-model | grep RM502Q-AE >> /dev/null && device=/dev/cdc-wdm0 || device=/dev/cdc-wdm1
sudo qmicli -d /dev/cdc-wdm0 --dms-get-model | grep RM502Q-AE >> /dev/null && iface=wwan0 || iface=wwan1

echo "Establishing 5g connection on device: ${device}, will use interface: ${iface}"

sudo qmicli -d /dev/cdc-wdm0 --nas-get-signal-info

# set apn, requires boot to take effect!
sudo qmicli -d $device --wds-modify-profile=3gpp,1,apn=$apn

echo "$device"
echo "Make sure reported APN below is same as script setting: $apn"
qmicli -d $device -p --wds-get-profile-list=3gpp | grep APN
while [ "$status" != "online" ]
do
	sleep 2
	temp=$(qmicli -d $device --dms-get-operating-mode)
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
# Start udhcpc for the interface
udhcpc -n -q -f -i $iface

# Add host route to waraps via $iface
#warapsip=$(getent hosts ome.waraps.org | awk '{print $1}')
warapsip=10.10.10.21
echo 'Add route to waraps ('$hostip') via interface '$iface
route add -host $hostip $iface
echo 'Add iptables postrouting rule'
iptables -t nat -A POSTROUTING -o $iface -m comment --comment "::Stream from jtx" -j MASQUERADE

# Put monitoring on the connecion. System service will restart as soon as this scrips exits
pingok=0
attemts=5
echo "Begin ping monitoring.."
echo ""
while [ $pingok -ne 1 ]; do
sleep 1
echo "send 5 pings to $pingip, if at least one is successful ping again"
# If no successful pings for 5-10s, break loop
# ping -Oc 5 8.8.8.8 > /dev/null && echo "up" || echo "down"
#ping -Oc 5 -W 1 $hostip > /dev/null && pingok=0 || pingok=1
ping -Oc 5 -W 1 $hostip -I $iface > /dev/null && pingok=0 || pingok=1
done
echo "No successful ping for 5-10s, restart service"
