## Prerequisites

An amd64-architecture host that supports (nested) virtualization. Modern Linux. Debian 12 preferred.

- QEMU KVM Hypervisor
- Docker daemon
- 20-40 GB free disk space (rough estimation)
- At least 4GB RAM (rough estimation)


## Steps

### Host setup

- Navigate to project root directory
- In case, fix permission
```shell
chmod +x daemon/*.sh
chmod +x vm/daemon/*.sh
chmod +x worker/*.sh
```
- Generate SSH keys
```shell
rm -rf vm/daemon/daemon
rm -rf vm/daemon/daemon.pub
rm -rf worker/worker
rm -rf worker/worker.pub
rm -rf daemon-to-host
rm -rf daemon-to-host.pub
# Generate whatever type of key you prefer
ssh-keygen -t rsa -b 2048 -f vm/daemon/daemon -N ""
ssh-keygen -t rsa -b 2048 -f worker/worker -N ""
ssh-keygen -t rsa -b 2048 -f daemon-to-host -N ""
```
- Designate a host user account that should be operating hypervisor.
- Add `daemon-to-host.pub` to `.ssh/authorized_keys`. Then reload/restart `sshd` service if necessary. (Or just use root for convenience.
  If to use non-root to operate hypervisor, don't forget to verify hypervisor configuration.
  And make sure the account has permission (without sudo), otherwise cannot create VM.)
- Set variables
```shell
# Use whichever QEMU KVM network interface you prefer.
export VM_NETWORK="default"
```
- Because systemd-resolved will be used in VM, make sure you designate an upstream DNS server for it:
```shell
# Set a variable. Will be used in install.sh script
export UPSTREAM_DNS="1.1.1.1"
```

### Daemon install

- Set variables
```shell
export GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE="gitea-actions-runner-daemon.qcow2"
export GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE_SIZE="10G"
export GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME="gitea-actions-runner-daemon-1"
export GITEA_ACTIONS_RUNNER_DAEMON_VM_DISK="daemon-1.qcow2"
```
- Navigate to `vm/daemon` directory
- Download [Gitea Act runner daemon][gitea_runner_daemon] executable as `gitea-actions-runner`
```shell
GITEA_ACTIONS_RUNNER_EXECUTABLE="https://github.com/CrimsonGiteaActions/ChristopherHX-gitea-actions-runner/releases/download/v0.0.16/ChristopherHX-gitea-actions-runner-0.0.16-linux-amd64"
wget -O "gitea-actions-runner" $GITEA_ACTIONS_RUNNER_EXECUTABLE
unset GITEA_ACTIONS_RUNNER_EXECUTABLE
```
- Run `install.sh`:
```shell
./install.sh --qcow2-output $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE --qcow2-size $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE_SIZE
```
- Start virtual machine:
```shell
qemu-img create -f qcow2 -b $GITEA_ACTIONS_RUNNER_DAEMON_BASE_IMAGE \
  -F qcow2 $GITEA_ACTIONS_RUNNER_DAEMON_VM_DISK </dev/null

virt-install --name $GITEA_ACTIONS_RUNNER_DAEMON_VM_NAME \
    --os-variant debian11 \
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
virsh net-dumpxml $VM_NETWORK
```

### VM network setup

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

### Worker image

- Set variables
```shell
export GITEA_ACTIONS_WORKER_BASE_IMAGE="debian-act-12.qcow2"
# Change values to whatever you like.
export GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE="14G"
```
- Navigate to `worker` directory
- Download [GitHub Runner][github_runner] tar.gz of Release asset as `runner.tar.gz`
```shell
GITHUB_RUNNER="https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz"
wget -O "runner.tar.gz" $GITHUB_RUNNER
unset GITHUB_RUNNER
```
- Run `install.sh`:
```shell
./install.sh --qcow2-output $GITEA_ACTIONS_WORKER_BASE_IMAGE  --qcow2-size $GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE
```

### Daemon setup

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
sftp -i vm/daemon/daemon -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
put daemon-to-host /root
EOS
ssh -i vm/daemon/daemon -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set -ex
chmod 400 daemon-to-host
EOS
```
- Set your variables and SSH into daemon VM to register Gitea act runner:
```shell
GITEA_INSTANCE_URL="https://gitea.com"   # Your Gitea instance 
GITEA_RUNNER_REGISTRATION_TOKEN="token"  # Your Gitea Runner registration token.
RUNNER_LABELS="debian-latest,debian-12"  # Your Gitea Runner labels
WORKING_DIR=$(pwd)
HOST_SSH_USER="root"           # Username used by daemon VM to reach host via SSH
HOST_SSH_HOST="192.168.122.1"  # IP address used by daemon VM to reach host via SSH
HOST_SSH_PORT="22"             # SSH port used by daemon VM to reach host via SSH
```
```shell
ssh -t -i $WORKING_DIR/vm/daemon/daemon \
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
ssh -t -i $WORKING_DIR/vm/daemon/daemon \
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
ssh -t -i $WORKING_DIR/vm/daemon/daemon \
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
```shell
ssh -t -i $WORKING_DIR/vm/daemon/daemon \
  -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@$DAEMON_VM_STATIC_IP <<EOS
set +o history
set -ex

systemctl restart gitea-actions-runner
sleep 1
systemctl status gitea-actions-runner

rm -rf ~/.bash_history
history -c
EOS
```

## Reference

- https://github.com/ChristopherHX/gitea-actions-runner


[gitea_runner_daemon]: https://github.com/CrimsonGiteaActions/ChristopherHX-gitea-actions-runner
[github_runner]: https://github.com/actions/runner
