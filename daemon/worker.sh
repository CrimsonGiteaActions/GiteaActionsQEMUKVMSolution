#!/bin/bash

# Gitea act runner daemon will call this script to reach the host responsible for running Worker VM

# Reach the host
host_ssh_username="root"
host_ssh_host="192.168.122.1"
host_ssh_port="22"
host_ssh_private_key=""

# On the host
worker_qcow2_image=""
worker_start_vm_script=""
worker_vm_ssh_key=""
worker_vm_network="default"
worker_vm_vcpus="1"
worker_vm_memory="2048"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long host-ssh-username:,host-ssh-host:,host-ssh-port:,host-ssh-private-key:,worker-qcow2-image:,worker-start-vm-script:,worker-vm-ssh-key:,worker-vm-network:,worker-vm-vcpus:,worker-vm-memory: \
  -- "$@")
eval set -- "$CMD_ARGS"

while true ; do
  case "$1" in
    --host-ssh-username)
      host_ssh_username=$2 ;
      shift 2 ;;
    --host-ssh-host)
      host_ssh_host=$2 ;
      shift 2 ;;
    --host-ssh-port)
      host_ssh_port=$2 ;
      shift 2 ;;
    --host-ssh-private-key)
      host_ssh_private_key=$2 ;
      shift 2 ;;
    --worker-qcow2-image)
      worker_qcow2_image=$2 ;
      shift 2 ;;
    --worker-start-vm-script)
      worker_start_vm_script=$2 ;
      shift 2 ;;
    --worker-vm-ssh-key)
      worker_vm_ssh_key=$2 ;
      shift 2 ;;
    --worker-vm-network)
      worker_vm_network=$2 ;
      shift 2 ;;
    --worker-vm-vcpus)
      worker_vm_vcpus=$2 ;
      shift 2 ;;
    --worker-vm-memory)
      worker_vm_memory=$2 ;
      shift 2 ;;
    --)
      shift 1 ;
      break ;;
    *)
      echo "Unknown: $1" ;
      exit 1 ;;
  esac
done

if [[ -z "$host_ssh_private_key" ]]; then
  echo "Specific ssh key to connect to host!"
  exit 1
fi

if [[ -z "$worker_start_vm_script" || -z "$worker_qcow2_image" || -z "$worker_vm_ssh_key" || -z "$worker_vm_network" || -z "$worker_vm_vcpus" || -z "$worker_vm_memory" ]]; then
  echo "Invalid worker setup!"
  exit 1
fi

# worker/worker.sh
ssh -i "$host_ssh_private_key" -p "$host_ssh_port" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$host_ssh_username@$host_ssh_host" \
  "bash $worker_start_vm_script --image $worker_qcow2_image --ssh-key $worker_vm_ssh_key --vm-network $worker_vm_network --vm-memory $worker_vm_memory --vm-vcpus $worker_vm_vcpus"