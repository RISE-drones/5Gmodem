# 5Gmodem
Short description for establishing 5G-connection with Quectel 5G modem.\
Many thanks and credits to M.M. from Ericsson who got me on track.

Here are notes from a work in progress. It is not a complete instruction or turn key solution, but it hopefully helps people to get along with 5G connections on different clients.

We have used a Quectel 5G modem and a carrier board XVIST 5G LTE Industrial m.2(NGFF) to USB3.0 Adapter that we got recommended. We bought it on amazon.\
We connect it to a raspberry Pi and powers it from a separate source (common ground). The Pi cannot supply the modem when it gets loaded.

# Contribute
Spread the word, and please suggest improvments or create pull requests!

# Prerequisits
Install libqmi-utils and udhcpc\
sudo apt install libqmi-utils\
sudo apt install udhcpc

Look for modem:\
usb-devices\
It should list the actual modem, Quectel RM500-GL in our case

ifconfig should list a wwanX interface. Check with lsusb and dmesg what interface the modem is connected to: You need to dig a bit if two modems are installed. In the mobile_connect_usb.sh we assume that RM500-GL in connected to wdm0 or wdm1.

sudo dmesg  | grep wwan

From here on, it is assumed the modem is connected to /dev/cdc-wdm0 or /dev/cdc-wdm1 and interface wwan0 or wwan1 respectivly. Adjust as nessesary for your setup.

# Antennas
The RM500-GL has four antenna connections. Our recommendation is to start laborating woth four antennas connected. As the modem connects properly, check what antenna ports are actually used by testing them one by one. I our case antanna conneciton 2 and 3 can run 5G private network standalone, therefore we use connections 2 and 3.
# Playing around with the modem
We use qmicli to communicate the modem. Here are some commands that can be played around with to familiarise with the modem. See these as notes of work in progress..

## Look for sim
Is sim there? (can take some time, be patient)\
sudo qmicli –d /dev/cdc-wdm0 –uim-get-slot-status
## APN
A bit mysterious. Apparently providers are sick of support issues regarding apn. Most providers approve 'internet' as apn..\
APN must be set correctly and often leads to problems. APN setting is valid after power cycle. Apn settings can change with sims, and possibly more events. If something does not work, start at the apn.\
Set the APN for next power cycle:\
sudo qmicli –d /dev/cdc-wdm1 --wds-modify-profile=3gpp,1,apn=internet\
sudo  qmicli -d /dev/cdc-wdm1 -p --wds-get-profile-list=3gpp

sudo qmicli –d &/dev/cdc-wdm1 --wds-start-network=apn=internet –cli-no-release-cid\
sudo udhcpc -q –n –f -I wwan1\
sudo qmicli –d &/dev/cdc-wdm1 --wds-get-current-settings

## The magic 5 lines (After setting up correctly we are good to go..)\
sudo ifconfig wwan1 down\
sudo qmicli -d /dev/cdc-wdm1 –set-expected-data-format=raw_ip (echo Y | sudo tee /sys/class/net/wwan1/qmi/raw_ip)\
sudo ifconfig wwan1 up\
sudo qmcli -d /dev/cdc-wdm1 --wds-start-network=apn=internet --client-no-release-cid\
sudo udhcpc -q -n -f -i wwan0     (note: No watchdog, if it goes down it goes down.)

What it does is that it puts down wwan1 so that we can write Y in the config file raw_ip, we then bring up the interface and start a connection and finally routes it.
## Quriosity commands, connection status etc:\
sudo qmicli –d /dev/cdc-wdm1 --nas-get-serving-system\
sudo qmicli –d /dev/cdc-wdm1 --nas-get-cell-location-info\
sudo qmicli –d /dev/cdc-wdm1 --nas-get-signal-info\
sudo qmicli –d /dev/cdc-wdm1 --wds-get-profile-list=3gpp\
sudo qmicli --nas-network-scan

# Autostart and maintain connection with usb modem
Create a script mobile_connect_usb.sh that connects and monitors the connection (available in repo)\
Adjust for path, apn, ping adress for testing the connection (googles DNS 8.8.8.8 is useful)\
cd /installation/modem/\
nano mobile_connect_usb.sh\
Add execution rights\
chmod 755 mobile_connect_usb.sh

Create a service that runs the scripts and restarts as soon as the scripts exits (available in repo)\
cd /etc/systemd/system/\
nano mobile_connect_usb.service\
Update your local path as nessesary

Test the service:\
sudo systemctl start mobile_connect_usb.service

Monitor the service, repeating prints "send 5 pings to 8.8.8.8…" is what we want\
sudo journalctl --follow -u mobile_connect_usb.service\
Try to unplug and plug in the device

If happy, enable the service and see how it works after cold start, reboot etc.\
sudo systemctl enable mobile_connect_usb.service
