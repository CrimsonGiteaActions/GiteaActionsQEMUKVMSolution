## Features

Run your Gitea Actions workflow in ephemeral virtual machine.

## Prerequisites

An amd64-architecture host that supports (nested) virtualization. Modern Linux. Debian/Ubuntu preferred.

For arm64, this solution should work in similar way. Not tested.

- QEMU KVM Hypervisor
- Docker daemon
- [d2vm]
- 20-40 GB free disk space (rough estimation)
- At least 4GB RAM (rough estimation)


**Build [d2vm] from source**:
```shell
GO_TAR="go1.23.4.linux-$(dpkg --print-architecture).tar.gz"
sudo rm -rf $GO_TAR
wget -O "$GO_TAR" -4 https://go.dev/dl/$GO_TAR
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf $GO_TAR
sudo rm -rf $GO_TAR
unset GO_TAR
export PATH=$PATH:/usr/local/go/bin
git clone https://github.com/linka-cloud/d2vm && cd d2vm
sudo rm -rf /usr/local/bin/d2vm
make install # No sudo here. If non-root user account, add to docker group first!
```
**Find `d2vm` executable in `~/go/bin` (if it's there. Refer to [d2vm] README for more info), move it to `$PATH`.**
```shell
sudo mv ~/go/bin/d2vm /usr/local/bin/
```


## Steps

### Host

- Navigate to project root directory
- In case, fix permission
```shell
chmod +x daemon/*.sh
chmod +x worker/*.sh
```
- Generate SSH keys
```shell
rm -rf daemon/daemon
rm -rf daemon/daemon.pub
rm -rf worker/worker
rm -rf worker/worker.pub
rm -rf daemon-to-host
rm -rf daemon-to-host.pub
# Generate whatever type of key you prefer
ssh-keygen -t rsa -b 2048 -f daemon/daemon -N ""
ssh-keygen -t rsa -b 2048 -f worker/worker -N ""
ssh-keygen -t rsa -b 2048 -f daemon-to-host -N ""
```
- Designate a host user account that should be operating hypervisor. 
- Add `daemon-to-host.pub` to `.ssh/authorized_keys`.
- Then reload/restart `sshd` service if necessary. (Or just use root for convenience.
If to use non-root to operate hypervisor, don't forget to verify hypervisor configuration.
And make sure the account has permission (without sudo), otherwise cannot create VM.)
- Set variables
```shell
# Use whichever QEMU KVM network interface you prefer.
export VM_NETWORK="default"
```

### Daemon

- Set variables
```shell
export GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE="ubuntu:22.04"
export GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE="gitea-actions-runner-daemon.qcow2"
export GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE_SIZE="10G"
export GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME="gitea-actions-runner-daemon-1"
export GITEA_ACTIONS_RUNNER_DAEMON_VM_DISK="daemon-1.qcow2"
```
- Navigate to `daemon` directory
- Download [Gitea Act runner daemon][gitea_runner] executable as `gitea-actions-runner`
```shell
GITEA_ACTIONS_RUNNER_EXECUTABLE="https://github.com/CrimsonGiteaActions/ChristopherHX-gitea-actions-runner/releases/download/v0.0.16/ChristopherHX-gitea-actions-runner-0.0.16-linux-amd64"
wget -O "gitea-actions-runner" $GITEA_ACTIONS_RUNNER_EXECUTABLE
unset GITEA_ACTIONS_RUNNER_EXECUTABLE
```
- Run `d2vm.sh`:
```shell
./d2vm.sh --docker-image $GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE \
  --qcow2-output $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE \
  --qcow2-size   $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE_SIZE
```
- Start virtual machine:
```shell
qemu-img create -f qcow2 -b $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE \
  -F qcow2 $GITEA_ACTIONS_RUNNER_DAEMON_VM_DISK </dev/null

virt-install --name $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME \
    --os-variant debian10 \
    --cpu host-passthrough \
    --disk $GITEA_ACTIONS_RUNNER_DAEMON_VM_DISK \
    --import \
    --vcpus 1 \
    --memory 512 \
    --network $VM_NETWORK \
    --graphics none \
    --noautoconsole </dev/null
```
- Take note of VM MAC address. If you manually set a MAC in `virt-install`, use your value then.
```shell
virsh domifaddr $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME
```
- Shutdown VM. Assign static IP to it.
```shell
virsh shutdown $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME
virsh net-edit $VM_NETWORK
```
`<network>` -> `<ip>` -> `<dhcp>`
```xml
<dhcp>
    <!--Change values to whatever you prefer.-->
  <range start="192.168.122.2" end="192.168.122.254"/>
  <host mac="YOUR:VM:MAC:ADDRESS" name="VM_NAME" ip="STATIC.IP"/>
</dhcp>
```
Then apply settings
```shell
virsh net-destroy $VM_NETWORK # Only if required.
virsh net-start $VM_NETWORK
virsh net-autostart $VM_NETWORK
```

### Host

- Designate a forwarder DNS IP (Optional):
`<network>` -> `<dns>`
```xml
<dns>
    <!--Change value to your DNS-->
    <forwarder addr='8.8.8.8'/>
</dns>
```
```shell
virsh net-destroy $VM_NETWORK # Only if required.
virsh net-start $VM_NETWORK
virsh net-autostart $VM_NETWORK
virsh net-dumpxml $VM_NETWORK
```

### Worker

- Set variables
```shell
# Change values to whatever you like.
export GITEA_ACTIONS_WORKER_DOCKER_IMAGE="ghcr.io/catthehacker/ubuntu:act-22.04"
export GITEA_ACTIONS_WORKER_BASE_IMAGE="ubuntu-act-2204.qcow2"
export GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE="14G"
```
- Navigate to `worker` directory
- Download [GitHub Runner][github_runner] tar.gz of Release asset as `runner.tar.gz`
```shell
GITHUB_RUNNER="https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz"
wget -O "runner.tar.gz" $GITHUB_RUNNER
unset GITHUB_RUNNER
```
- Run `d2vm.sh`:
```shell
./d2vm.sh --docker-image $GITEA_ACTIONS_WORKER_DOCKER_IMAGE \
  --qcow2-output $GITEA_ACTIONS_WORKER_BASE_IMAGE \
  --qcow2-size   $GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE
```

### Daemon

- Go back to project root directory. Set variable `DAEMON_VM_STATIC_IP` as previously set static IP
- Power on daemon VM. Verify IP is previously set static IP:
```shell
virsh start $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME
```
```shell
virsh domifaddr $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME
```
- Copy `daemon-to-host` SSH private key into daemon VM:
```shell
sftp -i daemon/daemon -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
put daemon-to-host /root
EOS
ssh -i daemon/daemon -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set -ex
chmod 400 daemon-to-host
EOS
```
- Set your variables and SSH into daemon VM to register Gitea act runner:
```shell
GITEA_INSTANCE_URL="https://gitea.com"   # Your Gitea instance 
GITEA_RUNNER_REGISTRATION_TOKEN="token"  # Your Gitea Runner registration token.
WORKING_DIR=$(pwd)
HOST_SSH_USER="root"           # Username used by daemon VM to reach host via SSH
HOST_SSH_HOST="192.168.122.1"  # IP address used by daemon VM to reach host via SSH
HOST_SSH_PORT="22"             # SSH port used by daemon VM to reach host via SSH
RUNNER_LABELS="ubuntu-latest,ubuntu-22.04"  # Your Gitea Runner labels
```
```shell
ssh -t -i $WORKING_DIR/daemon/daemon \
  -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set +o history
set -ex

/root/gitea-actions-runner register \
  --instance "$GITEA_INSTANCE_URL" \
  --token "$GITEA_RUNNER_REGISTRATION_TOKEN" \
  --worker "bash,/root/worker.sh,--host-ssh-user,$HOST_SSH_USER,--host-ssh-key,/root/daemon-to-host,--host-ssh-host,$HOST_SSH_HOST,--host-ssh-port,$HOST_SSH_PORT,--host-worker-script,$WORKING_DIR/worker/worker.sh,--host-worker-base-path,$WORKING_DIR/worker,--host-worker-image-name,$GITEA_ACTIONS_WORKER_BASE_IMAGE,--host-worker-ssh-key,$WORKING_DIR/worker/worker" \
  --labels "$RUNNER_LABELS" \
  --no-interactive

rm -rf ~/.bash_history
history -c
EOS

unset GITEA_RUNNER_REGISTRATION_TOKEN
```
- Make Gitea act runner daemon as a systemd service (Optional. Recommended.)
```shell
ssh -t -i $WORKING_DIR/daemon/daemon \
  -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set +o history
set -ex

cat << EOF > /etc/systemd/system/gitea-actions-runner.service
[Unit]
Description=Runner Proxy to use actions/runner and github-act-runner with Gitea Actions.
ConditionFileIsExecutable=/root/gitea-actions-runner

[Service]
Environment="GITEA_ACTIONS_RUNNER_OUTBOUND_IP=$DAEMON_VM_STATIC_IP"
StartLimitInterval=5
StartLimitBurst=10
WorkingDirectory=/root
ExecStart=/root/gitea-actions-runner daemon
Restart=always
RestartSec=10
EnvironmentFile=-/etc/sysconfig/gitea-actions-runner

[Install]
WantedBy=multi-user.target
EOF

cat /etc/systemd/system/gitea-actions-runner.service

systemctl daemon-reload
systemctl enable gitea-actions-runner

rm -rf ~/.bash_history
history -c
EOS
```
- Start Gitea act runner daemon,
  with `GITEA_ACTIONS_RUNNER_OUTBOUND_IP` environment variable set as daemon VM's static IP.
  Optionally, set `GITEA_ACTIONS_CACHE_SERVER_URL` to use a dedicated cache server instance.
```shell
ssh -t -i $WORKING_DIR/daemon/daemon \
  -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set +o history
set -ex

systemctl start gitea-actions-runner
sleep 1
systemctl status gitea-actions-runner
sleep 1
systemctl status gitea-actions-runner

rm -rf ~/.bash_history
history -c
EOS
```

## Reference

- https://github.com/ChristopherHX/gitea-actions-runner


[gitea_runner]: https://github.com/CrimsonGiteaActions/ChristopherHX-gitea-actions-runner
[github_runner]: https://github.com/actions/runner
[d2vm]: https://github.com/linka-cloud/d2vm