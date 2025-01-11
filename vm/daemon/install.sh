#!/bin/bash

set -o errexit -o pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
qcow2_image=$1

virt-customize -a $qcow2_image \
  --no-logfile \
  --hostname daemon \
  --copy-in $WORKING_DIR/gitea-actions-runner:/root/ \
  --copy-in $WORKING_DIR/../../daemon/worker.sh:/root/ \
  --run install0.sh \
  --copy-in $WORKING_DIR/sshd_config:/etc/ssh \
  --ssh-inject root:file:$WORKING_DIR/daemon.pub \
  --network \
  --memsize 1024
