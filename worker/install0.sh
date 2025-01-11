#!/bin/bash

set -e

apt-get -y update
apt-get -y install ca-certificates sed

sed -i 's/http/https/g' /etc/apt/sources.list

apt-get -y update
apt-get -y install curl make git vim nano sudo wget binutils unzip python3 qemu-guest-agent

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

########################################################################

apt-get -y upgrade

########################################################################

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf ~/.bash_history

########################################################################
