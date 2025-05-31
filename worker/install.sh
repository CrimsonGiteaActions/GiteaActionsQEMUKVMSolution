#!/bin/bash

set -o errexit -o pipefail
set -x

WORKING_DIR="$VMSETUP_WORKING_DIR_WORKER"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long "qcow2-output:,qcow2-size:,runner-variant:" \
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
    --runner-variant)
      runner_variant=$2 ;
      shift 2 ;;
    --)
      shift 1 ;
      break ;;
    *)
      echo "Unknown: $1" ;
      exit 1 ;;
  esac
done

runner_download_url=""
case "$runner_variant" in
  crimson)
    runner_download_url="https://github.com/CrimsonGiteaActions/github-runner/releases/download/v2.323.0%2Bcrimson/actions-runner-linux-x64-2.323.0+crimson.tar.gz" ;;
  chris)
    runner_download_url="https://github.com/ChristopherHX/runner.server/releases/download/v3.13.4/runner.server-linux-x64.tar.gz" ;;
  github)
    runner_download_url="https://github.com/actions/runner/releases/download/v2.324.0/actions-runner-linux-x64-2.324.0.tar.gz" ;;
  *)
    runner_variant="github" ;
    runner_download_url="https://github.com/actions/runner/releases/download/v2.324.0/actions-runner-linux-x64-2.324.0.tar.gz" ;;
esac

rm -rf "$WORKING_DIR/ufw-docker-after.rules"
rm -rf "$WORKING_DIR/actions-runner-worker.py"
cp "$WORKING_DIR/ufw-docker/after.rules" "$WORKING_DIR/ufw-docker-after.rules"
cp "$WORKING_DIR/ChristopherHX-gitea-actions-runner/actions-runner-worker.py" "$WORKING_DIR"
patch -p1 "$WORKING_DIR/actions-runner-worker.py" -i "$WORKING_DIR/actions-runner-worker.py.diff"

virt-builder debian-12 --size $qcow2_size \
  --check-signature \
  --arch amd64 \
  --format qcow2 \
  --no-logfile \
  --timezone UTC \
  --root-password disabled \
  --hostname worker \
  --copy-in "$WORKING_DIR/auto-shutdown:/etc/init.d/" \
  --copy-in "$WORKING_DIR/auto-startup:/etc/init.d/" \
  --run-command "chown root:root /etc/init.d/auto-shutdown" \
  --run-command "chown root:root /etc/init.d/auto-startup" \
  --run-command "chmod 755 /etc/init.d/auto-shutdown" \
  --run-command "chmod 755 /etc/init.d/auto-startup" \
  --run "$WORKING_DIR/install0.sh" \
  --run-command "ping -c 3 www.google.com" \
  --copy-in "$WORKING_DIR/ufw-docker-after.rules:/root/" \
  --run "$WORKING_DIR/install1.sh" \
  --ssh-inject "root:file:$WORKING_DIR/worker.pub" \
  --copy-in "$WORKING_DIR/sshd_config:/etc/ssh/" \
  --copy-in "$WORKING_DIR/sudoers:/etc/" \
  --run-command "chown root:root /etc/sudoers" \
  --run-command "chmod 0440 /etc/sudoers" \
  --run-command "visudo -c" \
  --run-command 'useradd -u 1000 -G sudo -m -s /bin/bash runner' \
  --run-command 'usermod -aG docker runner' \
  --run-command "curl -fL -o \"/home/runner/runner-$runner_variant.tar.gz\" \"$runner_download_url\"" \
  --run-command "chown runner:runner /home/runner/runner-$runner_variant.tar.gz" \
  --run-command "chmod 755 /home/runner/runner-$runner_variant.tar.gz" \
  --copy-in "$WORKING_DIR/actions-runner-worker.py:/home/runner/" \
  --run "$WORKING_DIR/install2.sh" \
  --network \
  --memsize 2048 \
  --output "$qcow2_output"

rm -rf "$WORKING_DIR/ufw-docker-after.rules"
rm -rf "$WORKING_DIR/actions-runner-worker.py"