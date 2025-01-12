#!/bin/bash

set -ex

WORKING_DIR=$(pwd)

########################################################################

git clone https://github.com/CrimsonGiteaActions/docker_images.git buildings
cd buildings

export NODE_VERSION="16 18"
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

rm -rf /tmp/*
rm -rf $WORKING_DIR/buildings
rm -rf /imagegeneration
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf ~/.bash_history

########################################################################
