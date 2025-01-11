#!/bin/bash

set -o errexit -o pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
qcow2_image=$1

virt-customize -a $qcow2_image \
  --no-logfile \
  --hostname worker \
  --copy-in $WORKING_DIR/auto-shutdown:/etc/init.d/ \
  --copy-in $WORKING_DIR/auto-startup:/etc/init.d/ \
  --run-command "chown root:root /etc/init.d/auto-shutdown" \
  --run-command "chown root:root /etc/init.d/auto-startup" \
  --run-command "chmod 755 /etc/init.d/auto-shutdown" \
  --run-command "chmod 755 /etc/init.d/auto-startup" \
  --run install0.sh \
  --ssh-inject root:file:$WORKING_DIR/worker.pub \
  --copy-in $WORKING_DIR/sshd_config:/etc/ssh/ \
  --copy-in $WORKING_DIR/sudoers:/etc/ \
  --run-command "chown root:root /etc/sudoers" \
  --run-command "chmod 0440 /etc/sudoers" \
  --run-command "visudo -c" \
  --run-command 'useradd -u 1000 -G sudo -m -s /bin/bash runner' \
  --run-command 'usermod -aG docker runner' \
  --copy-in $WORKING_DIR/runner.tar.gz:/home/runner/ \
  --copy-in $WORKING_DIR/vm_call_gh_worker.py:/home/runner/ \
  --run install1.sh \
  --network \
  --memsize 2048
