#!/bin/bash

# Using instructions from: 
# http://nicegear.co.nz/blog/using-an-i2c-real-time-clock-rtc-with-a-raspberry-pi/

# Remove RTC from blacklist, load module, notify linux
sudo sed -i 's/blacklist i2c-bcm2708/#blacklist i2c-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
sudo modprobe i2c-bcm2708
echo ds1307 0x68 | sudo tee /sys/class/i2c-adapter/i2c-1/new_device

# Set hardware clock the first time
sudo service ntp stop
sudo ntpd -gq
sudo service ntp start
sudo hwclock -w

# Update /etc/rc.local to start the hardware clock on boot and update the system time from the hardware clock
sudo sed -i 's#^exit 0$#echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-1/new_device#' /etc/rc.local
echo sudo hwclock -s | sudo tee -a /etc/rc.local
echo date | sudo tee -a /etc/rc.local
echo | sudo tee -a /etc/rc.local
echo exit 0 | sudo tee -a /etc/rc.local