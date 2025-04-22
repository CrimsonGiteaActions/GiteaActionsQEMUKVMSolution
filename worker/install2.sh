#!/bin/sh

set -ex

if ! (sudo -u runner groups | grep sudo); then
  echo "runner user is not in sudo group!!!"
  exit 1
fi

cd /home/runner

if [ -f "runner-crimson.tar.gz" ]; then
  mv "runner-crimson.tar.gz" "runner.tar.gz"
elif [ -f "runner-github.tar.gz" ]; then
  mv "runner-github.tar.gz" "runner.tar.gz"
elif [ -f "runner-chris.tar.gz" ]; then
  mkdir bin
  mv "runner-chris.tar.gz" "bin/runner.tar.gz"
  cd bin
else
  echo "Where's the runner.tar.gz?"
  exit 1
fi

tar -xzvf runner.tar.gz
rm -rf runner.tar.gz
chmod 555 /home/runner/bin/Runner.Worker

cd /home/runner
export RUNNER_CONTAINER_HOOKS_VERSION=0.7.0

wget --no-verbose -O runner-container-hooks.zip \
    "https://github.com/actions/runner-container-hooks/releases/download/v$RUNNER_CONTAINER_HOOKS_VERSION/actions-runner-hooks-docker-$RUNNER_CONTAINER_HOOKS_VERSION.zip" \
    && unzip ./runner-container-hooks.zip -d ./docker-hooks \
    && rm runner-container-hooks.zip

wget --no-verbose -O runner-container-hooks.zip \
    "https://github.com/actions/runner-container-hooks/releases/download/v$RUNNER_CONTAINER_HOOKS_VERSION/actions-runner-hooks-k8s-$RUNNER_CONTAINER_HOOKS_VERSION.zip" \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

mkdir -p _work
mkdir -p externals

apt-get update
apt-get install -y jq

jq --null-input \
  --arg agentName "runner" \
  --arg workFolder "/home/runner/_work" \
  '{ "isHostedServer": false, "agentName": $agentName, "workFolder": $workFolder }' > .runner
chmod 644 .runner

chown -R runner:docker .
chattr +i /home/runner/bin/Runner.Worker

echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> /root/.bashrc
echo "export GNUTLS_CPUID_OVERRIDE=0x1" >> .bashrc

systemctl enable ssh

apt-get clean
rm -rf ~/.bash_history
