#!/bin/bash

set -o errexit -o pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long qcow2-output:,qcow2-size: \
  -- "$@")
eval set -- "$CMD_ARGS"

qcow2_output="$WORKING_DIR/gitea-actions-runner-daemon.qcow2"
qcow2_size="10G"

while true ; do
  case "$1" in
    --qcow2-output)
      qcow2_output="$WORKING_DIR/$2" ;
      shift 2 ;;
    --qcow2-size)
      qcow2_size=$2 ;
      shift 2 ;;
    --)
      shift 1 ;
      break ;;
    *)
      echo "Unknown: $1" ;
      exit 1 ;;
  esac
done


rm -rf $WORKING_DIR/resolved.conf
cat <<EOF > $WORKING_DIR/resolved.conf
[Resolve]
DNS=$UPSTREAM_DNS
EOF


virt-builder debian-12 --size $qcow2_size \
  --check-signature \
  --arch amd64 \
  --format qcow2 \
  --no-logfile \
  --timezone UTC \
  --root-password disabled \
  --hostname daemon \
  --copy-in $WORKING_DIR/gitea-actions-runner:/root/ \
  --copy-in $WORKING_DIR/../../daemon/worker.sh:/root/ \
  --run install0.sh \
  --copy-in $WORKING_DIR/resolved.conf:/etc/systemd/ \
  --run-command "systemctl restart systemd-resolved" \
  --run-command "ping -c 3 www.google.com" \
  --copy-in $WORKING_DIR/sshd_config:/etc/ssh/ \
  --ssh-inject root:file:$WORKING_DIR/daemon.pub \
  --network \
  --memsize 2048 \
  --output $qcow2_output

rm -rf $WORKING_DIR/resolved.conf