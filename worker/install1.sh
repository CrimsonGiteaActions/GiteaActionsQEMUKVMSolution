#!/bin/sh

set -ex

WORKING_DIR=$(pwd)

########################################################################

git clone https://github.com/CrimsonGiteaActions/docker_images.git buildings
cd buildings

export NODE_VERSION="16 18 20 22"
export DISTRO="debian"
export TYPE="act"
export RUNNER="runner"
export DEBIAN_FRONTEND="noninteractive"

mkdir -p /imagegeneration/installers
cp -r ./linux/$DISTRO/scripts/* /imagegeneration/installers/
cd /tmp
chmod -R +x /imagegeneration/installers/*.sh
chmod -R +x /imagegeneration/installers/helpers/*.sh
bash /imagegeneration/installers/$TYPE.sh

########################################################################

# https://docs.docker.com/engine/install/debian/
apt-get -y update
apt-get -y install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

########################################################################

cat /root/ufw-docker-after.rules >> /etc/ufw/after.rules
ufw reload
rm -rf /root/ufw-docker-after.rules

########################################################################

rm -rf /tmp/*
rm -rf $WORKING_DIR/buildings
rm -rf /imagegeneration
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf ~/.bash_history

########################################################################
