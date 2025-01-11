#!/bin/bash

host_ssh_username="root"
host_ssh_host="192.168.122.1"
host_ssh_port="22"
host_ssh_private_key=""

host_worker_script=""
host_qcow2_base_path=""
host_qcow2_imagename=""
host_worker_ssh_key=""
host_vm_network="default"
host_vm_vcpus="2"
host_vm_memory="4096"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long host-ssh-user:,host-ssh-host:,host-ssh-port:,host-ssh-key:,host-worker-script:,host-worker-base-path:,host-worker-image-name:,host-worker-ssh-key:,host-worker-vm-vcpus:,host-worker-vm-memory: \
  -- "$@")
eval set -- "$CMD_ARGS"

while true ; do
  case "$1" in
    --host-ssh-user)
      host_ssh_username=$2 ;
      shift 2 ;;
    --host-ssh-host)
      host_ssh_host=$2 ;
      shift 2 ;;
    --host-ssh-port)
      host_ssh_port=$2 ;
      shift 2 ;;
    --host-ssh-key)
      host_ssh_private_key=$2 ;
      shift 2 ;;
    --host-worker-script)
      host_worker_script=$2 ;
      shift 2 ;;
    --host-worker-base-path)
      host_qcow2_base_path=$2 ;
      shift 2 ;;
    --host-worker-image-name)
      host_qcow2_imagename=$2 ;
      shift 2 ;;
    --host-worker-ssh-key)
      host_worker_ssh_key=$2 ;
      shift 2 ;;
    --host-worker-vm-network)
      host_vm_network=$2 ;
      shift 2 ;;
    --host-worker-vm-vcpus)
      host_vm_vcpus=$2 ;
      shift 2 ;;
    --host-worker-vm-memory)
      host_vm_memory=$2 ;
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

if [[ -z "$host_worker_script" || -z "$host_qcow2_base_path" || -z "$host_qcow2_imagename" || -z "$host_worker_ssh_key" ]]; then
  echo "Invalid worker setup!"
  exit 1
fi

# worker/worker.sh
ssh -i "$host_ssh_private_key" -p "$host_ssh_port" -o BatchMode=yes -o ForwardAgent=no -o IdentitiesOnly=yes -o StrictHostKeyChecking=no "$host_ssh_username@$host_ssh_host" \
  "bash $host_worker_script --base-path $host_qcow2_base_path --image-name $host_qcow2_imagename --ssh-key $host_worker_ssh_key --vm-network $host_vm_network --vm-memory $host_vm_memory --vm-vcpus $host_vm_vcpus"