#!/bin/bash

set -eo pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long base-path:,image-name:,ssh-key:,vm-vcpus:,vm-memory:,vm-network: \
  -- "$@")
eval set -- "$CMD_ARGS"

qcow2_base_path=""
qcow2_imagename=""
worker_ssh_key=""

VM_NETWORK="default"
VM_VCPUS="2"
VM_MEMORY_MB="4096"

while true ; do
  case "$1" in
    --base-path)
      qcow2_base_path=$2 ;
      shift 2 ;;
    --image-name)
      qcow2_imagename=$2 ;
      shift 2 ;;
    --ssh-key)
      worker_ssh_key=$2 ;
      shift 2 ;;
    --vm-network)
      VM_NETWORK=$2 ;
      shift 2 ;;
    --vm-vcpus)
      VM_VCPUS=$2 ;
      shift 2 ;;
    --vm-memory)
      VM_MEMORY_MB=$2 ;
      shift 2 ;;
    --)
      shift 1 ;
      break ;;
    *)
      echo "Unknown: $1" ;
      exit 1 ;;
  esac
done

if [[ -z "$qcow2_base_path" || -z "$qcow2_imagename" || -z "$worker_ssh_key" ]]; then
  echo "Invalid worker setup!"
  exit 1
fi

VM_BASE_IMAGE_PATH=$qcow2_base_path
VM_BASE_IMAGE="$VM_BASE_IMAGE_PATH/$qcow2_imagename"
VM_ID="gitea-action-$(openssl rand -hex 32)"
VM_IMAGE="$VM_BASE_IMAGE_PATH/$VM_ID.qcow2"
VM_SSH_KEY="$worker_ssh_key"

get_vm_ip() {
  (virsh -q domifaddr "$VM_ID" | awk '{print $4}' | sed -E 's/\/[0-9]+$//g') </dev/null
}

destroy_vm() {
  echo "Removing"
  (virsh destroy "$VM_ID" || true) </dev/null
  (virsh undefine "$VM_ID" || true) </dev/null
  if [ -f "$VM_IMAGE" ]; then
    rm -rf "$VM_IMAGE" </dev/null
  fi
  exit
}

trap destroy_vm ERR EXIT SIGINT SIGTERM

prepare_vm() {
  echo "Preparing"
  qemu-img create -f qcow2 -b "$VM_BASE_IMAGE" "$VM_IMAGE" -F qcow2 </dev/null
  # https://serverfault.com/questions/1167930/gnutls-error-signal-4-on-qemu-kvm-with-cpu-set-to-host-model
  virt-install --name "$VM_ID" --os-variant debian10 \
    --cpu host-passthrough \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus $VM_VCPUS \
    --memory $VM_MEMORY_MB \
    --network $VM_NETWORK \
    --graphics none \
    --noautoconsole </dev/null

  echo "Waiting for virtual machine to boot up"
  for i in $(seq 1 60); do
    VM_IP=$(get_vm_ip)
    if [ -n "$VM_IP" ]; then
      break
    fi

    if [ "$i" == "60" ]; then
      echo "Booting timed out!!!"
      destroy_vm
    fi
    sleep 1
  done

  echo "Waiting"
  for i in $(seq 1 60); do
    if ssh -n -i "$VM_SSH_KEY" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@"$VM_IP" exit </dev/null ; then
      break
    fi

    if [ "$i" == "60" ]; then
      echo "Terminal unreachable!!!"
      destroy_vm
    fi
    sleep 1
  done
}

run_job() {
  VM_IP=$(get_vm_ip)
  echo "Running job"
  ssh -t -i "$VM_SSH_KEY" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@"$VM_IP" "export HOME=/home/runner; cd /home/runner; python3 vm_call_gh_worker.py runner docker /home/runner/bin/Runner.Worker"
  if [ $? -ne 0 ]; then
    echo "Job execution not successful."
  fi
  destroy_vm
}

prepare_vm
run_job
