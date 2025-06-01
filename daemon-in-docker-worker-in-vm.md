## Prerequisites

An amd64-architecture host that supports virtualization. Modern Linux. Debian 12 preferred.

> [!WARNING]
> Nested virtualization not recommended, as it could be faulty for host kernel.

- QEMU KVM Hypervisor
  - deb: `sudo apt-get install libguestfs-tools qemu-system libvirt-clients libvirt-daemon-system`
- Docker daemon
- Git
- Roughly 20GB free disk space
- Roughly 4GB free RAM (More RAM better)
- A powerful CPU

## Steps

### Host setup

Enter project root directory:
```shell
git submodule update --init --recursive
export VMSETUP_WORKING_DIR=$(pwd)
export VMSETUP_WORKING_DIR_DAEMON="$VMSETUP_WORKING_DIR/daemon"
export VMSETUP_WORKING_DIR_DOCKER_DAEMON="$VMSETUP_WORKING_DIR/docker/daemon"
export VMSETUP_WORKING_DIR_WORKER="$VMSETUP_WORKING_DIR/worker"
```
```shell
export VMSETUP_WORKER_PUBKEY="$VMSETUP_WORKING_DIR_WORKER/worker.pub"
export VMSETUP_WORKER_PRIVKEY="$VMSETUP_WORKING_DIR_WORKER/worker"
export VMSETUP_DAEMON_TO_HOST_PUBKEY="$VMSETUP_WORKING_DIR/daemon-to-host.pub"
export VMSETUP_DAEMON_TO_HOST_PRIVKEY="$VMSETUP_WORKING_DIR/daemon-to-host"
rm -rf $VMSETUP_WORKER_PRIVKEY
rm -rf $VMSETUP_WORKER_PUBKEY
rm -rf $VMSETUP_DAEMON_TO_HOST_PRIVKEY
rm -rf $VMSETUP_DAEMON_TO_HOST_PUBKEY
# Generate whatever type of key you prefer
ssh-keygen -t rsa -b 2048 -f "$VMSETUP_WORKER_PRIVKEY" -N ""
ssh-keygen -t rsa -b 2048 -f "$VMSETUP_DAEMON_TO_HOST_PRIVKEY" -N ""
```
Remember to add `daemon-to-host.pub` to host `.ssh/authorized_keys`:
```shell
cat "$VMSETUP_DAEMON_TO_HOST_PUBKEY" >> ~/.ssh/authorized_keys
```

### Daemon install

- Set variables:
```shell
# Change values to whatever you prefer
export GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE="ubuntu:22.04"
export GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG="gitea-actions-runner-daemon:local"
export GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME="gitea-actions-runner-daemon-1"
```
- Run `build.sh`:
```shell
"$VMSETUP_WORKING_DIR_DOCKER_DAEMON/build.sh" \
  --docker-image "$GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE" \
  --docker-tag "$GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG"
```

### VM network setup

```shell
# Change value to whichever QEMU KVM network interface you prefer.
export VM_NETWORK="default"
```
- Designate a forwarder DNS IP for `VM_NETWORK` (Optional):
```shell
virsh net-edit $VM_NETWORK
```
Use whatever DNS you prefer:
```xml
<network>
<dns>
    <forwarder addr='1.1.1.1'/>
</dns>
</network>
```
```shell
virsh net-destroy $VM_NETWORK # Only if required.
virsh net-start $VM_NETWORK
virsh net-autostart $VM_NETWORK
virsh net-dumpxml $VM_NETWORK
```

### Worker VM image

- Set variables:
```shell
# Change values to whatever you prefer.
export GITEA_ACTIONS_WORKER_BASE_IMAGE_NAME="debian-act-12.qcow2"
export GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE="14G"
```
- Run `install.sh`:
```shell
rm -rf $VMSETUP_WORKING_DIR_WORKER/$GITEA_ACTIONS_WORKER_BASE_IMAGE_NAME
```
```shell
# Runner variants: crimson, chris, github
# crimson: CrimsonGiteaActions/github-runner
# chris: ChristopherHX/runner.server
# github: actions/runner
"$VMSETUP_WORKING_DIR_WORKER/install.sh" \
  --qcow2-output "$GITEA_ACTIONS_WORKER_BASE_IMAGE_NAME" \
  --qcow2-size "$GITEA_ACTIONS_WORKER_BASE_IMAGE_SIZE" \
  --runner-variant "crimson"
```

### Daemon setup

- Set variables for Gitea act runner registration:
```shell
export GITEA_INSTANCE_URL="https://gitea.com"   # Your Gitea instance 
export GITEA_RUNNER_REGISTRATION_TOKEN="token"  # Your Gitea Act Runner registration token.
```
- Create a Docker network. Designate a static IP for daemon container to use.
```shell
# Change values to whatever you prefer.
export DAEMON_CONTAINER_STATIC_IP="172.19.0.3"
export DAEMON_CONTAINER_NETWORK_NAME="gitea-act-runner"
export DAEMON_CONTAINER_NETWORK_SUBNET="172.19.0.0/24"

docker network rm $DAEMON_CONTAINER_NETWORK_NAME
docker network create --driver bridge --subnet $DAEMON_CONTAINER_NETWORK_SUBNET $DAEMON_CONTAINER_NETWORK_NAME
```
```shell
export HOST_SSH_USER="root"  # Username used by daemon to reach host via SSH
export HOST_SSH_HOST="172.19.0.1"  # IP address used by daemon to reach host via SSH
export HOST_SSH_PORT="22"          # SSH port used by daemon to reach host via SSH
export RUNNER_LABELS="debian-latest,debian-12"  # Your Gitea Act Runner labels
export GITEA_RUNNER_WORKER="bash,/home/runner/worker.sh,--host-ssh-host,$HOST_SSH_HOST,--host-ssh-port,$HOST_SSH_PORT,--host-ssh-username,$HOST_SSH_USER,--host-ssh-private-key,/home/runner/daemon-to-host,--worker-start-vm-script,$VMSETUP_WORKING_DIR_WORKER/worker.sh,--worker-qcow2-image,$VMSETUP_WORKING_DIR_WORKER/$GITEA_ACTIONS_WORKER_BASE_IMAGE_NAME,--worker-vm-ssh-key,$VMSETUP_WORKER_PRIVKEY,--worker-vm-network,$VM_NETWORK"
echo $GITEA_RUNNER_WORKER
```
- Register Gitea act runner and Start Gitea act runner daemon,
  with `GITEA_ACTIONS_RUNNER_OUTBOUND_IP` environment variable set as daemon container's static IP.
  Optionally, set `GITEA_ACTIONS_CACHE_SERVER_URL` to use a dedicated cache server instance.
```shell
rm -rf $VMSETUP_WORKING_DIR/.runner
touch $VMSETUP_WORKING_DIR/.runner
chown 1000:1000 $VMSETUP_WORKING_DIR/.runner
docker container rm -f $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME
docker run -itd \
  --name $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME \
  --ip $DAEMON_CONTAINER_STATIC_IP \
  --network $DAEMON_CONTAINER_NETWORK_NAME \
  -m 256MB \
  --restart unless-stopped \
  --volume $VMSETUP_WORKING_DIR/.runner:/home/runner/.runner:rw \
  -e GITEA_ACTIONS_RUNNER_OUTBOUND_IP=$DAEMON_CONTAINER_STATIC_IP \
  -e GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL \
  -e HOST_SSH_USER=$HOST_SSH_USER \
  -e HOST_SSH_HOST=$HOST_SSH_HOST \
  -e HOST_SSH_PORT=$HOST_SSH_PORT \
  -e RUNNER_LABELS=$RUNNER_LABELS \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=$GITEA_RUNNER_REGISTRATION_TOKEN \
  -e GITEA_RUNNER_WORKER=$GITEA_RUNNER_WORKER \
  -e GITEA_RUNNER_ONCE=1 \
  $GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG

docker cp "$VMSETUP_DAEMON_TO_HOST_PRIVKEY" "$GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME:/home/runner/"
docker exec --user root "$GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME" chmod 0400 /home/runner/daemon-to-host
docker exec --user root "$GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME" chown runner:runner /home/runner/daemon-to-host
docker exec --user root "$GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME" ls -alh /home/runner

unset GITEA_RUNNER_REGISTRATION_TOKEN
```

## Notes

> [!NOTE]
> Procedure:
> 1. Gitea act runner daemon fetches a task from Gitea.
> 2. The daemon calls script to reach host that's responsible for running worker VM.
> 3. On the host a worker VM is installed and booted.
> 4. Automatically SSH into the worker VM to call a Python script that starts GitHub Runner inside, with contextual information for the runner.
> 5. The GitHub Runner contacts Gitea act runner daemon back so to start and run job.
> 6. The daemon interprets information from the GitHub Runner and reports back to Gitea.
> 7. Finally on job end, the worker VM gets removed.

> [!WARNING]
> - Firewall (e.g. iptables) may prevent GitHub Runner (that's inside worker VM) from reaching the Gitea act runner daemon. (`ufw route allow from 192.168.122.0/24`)
> - Iptables rules added by Docker daemon may prevent GitHub Runner from reaching the Gitea act runner daemon.

> [!IMPORTANT]
> - On the host give `libvirt-qemu` full `rwx` access to the project directory (`chmod`, `setfacl`), otherwise could fail to create qcow2 for creating VM.
> - Modify `.runner` file to alter `runner_worker`, restart daemon.

> [!TIP]
> - Use `worker` key to SSH into worker VM manually.
> - Don't leave nested KVM running too long.
> - This solution is tested on host with IPv4/IPv6 forwarding enabled:
```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
```

> [!TIP]
> Initially this solution was done on 2 hosts, one dedicated to running Gitea and the other one had Gitea act daemon and worker VM.

## Reference

[ChristopherHX/gitea-actions-runner](https://github.com/ChristopherHX/gitea-actions-runner)