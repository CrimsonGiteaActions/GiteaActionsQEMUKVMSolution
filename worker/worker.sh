#!/bin/bash

# This script is put on the host responsible for running Worker VM

set -eo pipefail

CMD_ARGS=$(getopt -a \
  -o "" \
  --long image:,ssh-key:,vm-vcpus:,vm-memory:,vm-network: \
  -- "$@")
eval set -- "$CMD_ARGS"

qcow2_image=""
worker_vm_ssh_key=""

VM_NETWORK="default"
VM_VCPUS="1"
VM_MEMORY_MB="2048"

while true ; do
  case "$1" in
    --image)
      qcow2_image=$2 ;
      shift 2 ;;
    --ssh-key)
      worker_vm_ssh_key=$2 ;
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

if [[ -z "$qcow2_image" || -z "$worker_vm_ssh_key" ]]; then
  echo "Invalid worker setup!"
  exit 1
fi

VM_BASE_IMAGE_PATH="$(cd "$(dirname "$qcow2_image")" && pwd)"
VM_BASE_IMAGE="$qcow2_image"
VM_ID="gitea-action-$(openssl rand -hex 16)"
VM_IMAGE="$VM_BASE_IMAGE_PATH/$VM_ID.qcow2"
VM_SSH_KEY="$worker_vm_ssh_key"

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
  # https://manpages.debian.org/unstable/virtinst/virt-install.1.en.html
  # https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-manipulating_the_domain_xml-cpu_model_and_topology#sect-Manipulating_the_domain_xml-CPU_model_and_topology
  virt-install --name "$VM_ID" --os-variant debian11 \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus $VM_VCPUS \
    --memory $VM_MEMORY_MB \
    --network $VM_NETWORK \
    --graphics none \
    --noautoconsole </dev/null

  echo "Waiting for virtual machine to boot up"
  for i in $(seq 1 300); do
    VM_IP=$(get_vm_ip)
    if [ -n "$VM_IP" ]; then
      break
    fi

    if [ "$i" == "300" ]; then
      echo "Booting timed out!!!"
      destroy_vm
    fi
    sleep 1
  done

  echo "Waiting"
  for i in $(seq 1 300); do
    if ssh -n -i "$VM_SSH_KEY" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@"$VM_IP" exit </dev/null ; then
      break
    fi

    if [ "$i" == "300" ]; then
      echo "Terminal unreachable!!!"
      destroy_vm
    fi
    sleep 1
  done
}

run_job() {
  VM_IP=$(get_vm_ip)
  echo "Running job"
  ssh -t -i "$VM_SSH_KEY" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no root@"$VM_IP" "export HOME=/home/runner; cd /home/runner; python3 actions-runner-worker.py runner docker /home/runner/bin/Runner.Worker"
  if [ $? -ne 0 ]; then
    echo "Job execution not successful."
  fi
  destroy_vm
}

prepare_vm
run_job
