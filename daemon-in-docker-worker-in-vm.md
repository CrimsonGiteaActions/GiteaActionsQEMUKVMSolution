## Prerequisites

Refer to [Daemon and Worker in VM](./daemon-and-worker-in-vm.md#prerequisites)

## Steps

### Host setup

```shell
chmod +x daemon/*.sh
chmod +x docker/daemon/*.sh
chmod +x worker/*.sh
```
```shell
rm -rf worker/worker
rm -rf worker/worker.pub
rm -rf daemon-to-host
rm -rf daemon-to-host.pub
# Generate whatever type of key you prefer
ssh-keygen -t rsa -b 2048 -f worker/worker -N ""
ssh-keygen -t rsa -b 2048 -f daemon-to-host -N ""
```
```shell
# Use whichever QEMU KVM network interface you prefer.
export VM_NETWORK="default"
```

### Daemon install

- Set variables
```shell
export GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE="ubuntu:22.04"
export GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG="gitea-actions-runner-daemon:local"
export GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME="gitea-actions-runner-daemon-1"
```
- Navigate to `docker/daemon` directory
```shell
GITEA_ACTIONS_RUNNER_EXECUTABLE="https://github.com/CrimsonGiteaActions/ChristopherHX-gitea-actions-runner/releases/download/v0.0.16/ChristopherHX-gitea-actions-runner-0.0.16-linux-amd64"
wget -O "gitea-actions-runner" $GITEA_ACTIONS_RUNNER_EXECUTABLE
unset GITEA_ACTIONS_RUNNER_EXECUTABLE
```
- Run `build.sh`
```shell
./build.sh --docker-image $GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_IMAGE --docker-tag $GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG
```

### VM network setup

Follow steps in [Daemon and Worker in VM](./daemon-and-worker-in-vm.md#vm-network-setup)

### Worker image

Follow steps in [Daemon and Worker in VM](./daemon-and-worker-in-vm.md#worker-image)

### Daemon setup

- Go back to project root directory.
- Set your variables for Gitea act runner registration
```shell
GITEA_INSTANCE_URL="https://gitea.com"   # Your Gitea instance 
GITEA_RUNNER_REGISTRATION_TOKEN="token"  # Your Gitea Runner registration token.
WORKING_DIR=$(pwd)
HOST_SSH_USER="root"        # Username used by daemon container to reach host via SSH
RUNNER_LABELS="ubuntu-latest,ubuntu-22.04"  # Your Gitea Runner labels
```
- Create a Docker network. Designate a static IP for daemon container to use.
```shell
# Change variables to whatever you prefer.
export DAEMON_CONTAINER_STATIC_IP="172.19.0.3"
export DAEMON_CONTAINER_NETWORK_NAME="gitea-act-runner"
export DAEMON_CONTAINER_NETWORK_SUBNET="172.19.0.0/24"
HOST_SSH_HOST="172.19.0.1"  # IP address used by daemon container to reach host via SSH
HOST_SSH_PORT="22"          # SSH port used by daemon container to reach host via SSH
export GITEA_RUNNER_WORKER="bash,/home/runner/worker.sh,--host-ssh-user,$HOST_SSH_USER,--host-ssh-key,/home/runner/daemon-to-host,--host-ssh-host,$HOST_SSH_HOST,--host-ssh-port,$HOST_SSH_PORT,--host-worker-script,$WORKING_DIR/worker/worker.sh,--host-worker-base-path,$WORKING_DIR/worker,--host-worker-image-name,$GITEA_ACTIONS_WORKER_BASE_IMAGE,--host-worker-ssh-key,$WORKING_DIR/worker/worker"
echo $GITEA_RUNNER_WORKER

docker network rm $DAEMON_CONTAINER_NETWORK_NAME
docker network create --driver bridge --subnet $DAEMON_CONTAINER_NETWORK_SUBNET $DAEMON_CONTAINER_NETWORK_NAME
```
- Register Gitea act runner and Start Gitea act runner daemon,
  with `GITEA_ACTIONS_RUNNER_OUTBOUND_IP` environment variable set as daemon container's static IP.
  Optionally, set `GITEA_ACTIONS_CACHE_SERVER_URL` to use a dedicated cache server instance.
```shell
rm -rf $WORKING_DIR/.runner
touch $WORKING_DIR/.runner
chown 1000:1000 $WORKING_DIR/.runner
docker run -itd --restart unless-stopped --name $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME \
  --network $DAEMON_CONTAINER_NETWORK_NAME \
  --ip $DAEMON_CONTAINER_STATIC_IP \
  --cpus 1 \
  -m 256MB \
  -e GITEA_ACTIONS_RUNNER_OUTBOUND_IP=$DAEMON_CONTAINER_STATIC_IP \
  -e GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL \
  -e HOST_SSH_USER=$HOST_SSH_USER \
  -e HOST_SSH_HOST=$HOST_SSH_HOST \
  -e HOST_SSH_PORT=$HOST_SSH_PORT \
  -e RUNNER_LABELS=$RUNNER_LABELS \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=$GITEA_RUNNER_REGISTRATION_TOKEN \
  -e GITEA_RUNNER_WORKER=$GITEA_RUNNER_WORKER \
  -e GITEA_RUNNER_ONCE=1 \
  --volume $WORKING_DIR/.runner:/home/runner/.runner:rw \
  $GITEA_ACTIONS_RUNNER_DAEMON_DOCKER_TAG

docker cp $WORKING_DIR/daemon-to-host $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME:/home/runner/
docker exec --user root $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME chmod 0400 /home/runner/daemon-to-host
docker exec --user root $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME chown runner:runner /home/runner/daemon-to-host
docker exec --user root $GITEA_ACTIONS_RUNNER_DAEMON_CONTAINER_NAME ls -alh /home/runner

unset GITEA_RUNNER_WORKER
unset GITEA_RUNNER_REGISTRATION_TOKEN
```


## Reference

See [Daemon and Worker in VM](./daemon-and-worker-in-vm.md#reference)