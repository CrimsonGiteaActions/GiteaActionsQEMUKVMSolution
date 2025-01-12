#!/bin/bash

set -ex

sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo 'auto eth0' >> /etc/network/interfaces
echo 'allow-hotplug eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces

chmod 750 /root/gitea-actions-runner
chmod 750 /root/worker.sh

apt-get -y update
apt-get -y install ca-certificates curl vim nano sudo wget binutils unzip tar qemu-guest-agent \
  openssh-server openssh-sftp-server openssh-client cron net-tools iputils-ping dnsutils systemd-resolved

########################################################################

systemctl enable cron
systemctl start cron
(crontab -l 2>/dev/null; echo "*/10 * * * * journalctl --vacuum-size 1K") | crontab -
systemctl restart cron

########################################################################

echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> /root/.bashrc
echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> .bashrc

systemctl enable ssh
systemctl enable systemd-resolved
systemctl start systemd-resolved

apt-get clean
rm -rf ~/.bash_history

########################################################################
