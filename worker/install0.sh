#!/bin/sh

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
apt-get -y install tar curl make cmake git vim nano sudo wget binutils unzip python3 qemu-guest-agent ufw bash libssl-dev openssl zlib1g-dev libpcre2-dev

ufw default deny incoming
ufw default deny routed
ufw allow 22/tcp
ufw enable
