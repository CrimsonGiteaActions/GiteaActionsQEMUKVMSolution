#!/bin/bash

set -ex

sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo 'auto eth0' >> /etc/network/interfaces
echo 'allow-hotplug eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces

apt-get -y update
apt-get -y install ca-certificates sed

sed -i 's/http/https/g' /etc/apt/sources.list

apt-get -y update
apt-get -y install curl make git vim nano sudo wget binutils unzip python3 qemu-guest-agent systemd-resolved
