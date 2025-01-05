#!/bin/bash

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -o errexit -o pipefail

CMD_ARGS=$(getopt -a \
  -o "" \
  --long docker-image:,qcow2-output:,qcow2-size: \
  -- "$@")
eval set -- "$CMD_ARGS"

docker_image="ubuntu:22.04"
qcow2_output="$WORKING_DIR/gitea-actions-runner-daemon.qcow2"
qcow2_size="10G"

while true ; do
  case "$1" in
    --docker-image)
      docker_image=$2 ;
      shift 2 ;;
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

echo "Pull $docker_image and convert to $qcow2_output with maximum size $qcow2_size"

docker pull $docker_image

d2vm convert $docker_image \
  --platform linux/$(dpkg --print-architecture) \
  --network-manager ifupdown \
  --output $qcow2_output \
  --size $qcow2_size \
  --split-boot \
  --verbose \
  --password $(openssl rand -hex 32) \
  --force

$WORKING_DIR/install.sh $qcow2_output
