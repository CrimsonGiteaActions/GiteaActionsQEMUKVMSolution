#!/bin/bash

set -ex

chmod 750 /root/gitea-actions-runner
chmod 750 /root/worker.sh

apt-get -y update
apt-get -y install ca-certificates curl vim nano sudo wget binutils unzip tar qemu-guest-agent \
  openssh-server openssh-sftp-server openssh-client cron

########################################################################

systemctl enable cron
systemctl start cron
(crontab -l 2>/dev/null; echo "*/10 * * * * journalctl --vacuum-size 1K") | crontab -
systemctl restart cron

########################################################################

echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> /root/.bashrc
echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> .bashrc

systemctl enable ssh

cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.53
EOF
chattr +i /etc/resolv.conf

apt-get clean
rm -rf ~/.bash_history

########################################################################
