#!/bin/bash

set -o errexit -o pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long qcow2-output:,qcow2-size: \
  -- "$@")
eval set -- "$CMD_ARGS"

qcow2_output="$WORKING_DIR/debian-act-11.qcow2"
qcow2_size="14G"

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
  --hostname worker \
  --copy-in $WORKING_DIR/auto-shutdown:/etc/init.d/ \
  --copy-in $WORKING_DIR/auto-startup:/etc/init.d/ \
  --run-command "chown root:root /etc/init.d/auto-shutdown" \
  --run-command "chown root:root /etc/init.d/auto-startup" \
  --run-command "chmod 755 /etc/init.d/auto-shutdown" \
  --run-command "chmod 755 /etc/init.d/auto-startup" \
  --run install0.sh \
  --copy-in $WORKING_DIR/resolved.conf:/etc/systemd/ \
  --run-command "systemctl restart systemd-resolved" \
  --run-command "ping -c 3 www.google.com" \
  --run install1.sh \
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
  --run install2.sh \
  --network \
  --memsize 2048 \
  --output $qcow2_output

rm -rf $WORKING_DIR/resolved.conf