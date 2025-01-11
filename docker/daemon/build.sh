#!/bin/bash

set -o errexit -o pipefail

WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD_ARGS=$(getopt -a \
  -o "" \
  --long docker-image:,docker-tag: \
  -- "$@")
eval set -- "$CMD_ARGS"

docker_image="ubuntu:22.04"
docker_tag="gitea-actions-runner-daemon:local"

while true ; do
  case "$1" in
    --docker-image)
      docker_image="$2" ;
      shift 2 ;;
    --docker-tag)
      docker_tag="$2" ;
      shift 2 ;;
    --)
      shift 1 ;
      break ;;
    *)
      echo "Unknown: $1" ;
      exit 1 ;;
  esac
done

export DOCKER_BUILD_KIT=1
export DOCKER_CLI_EXPERIMENTAL=1

rm -rf $WORKING_DIR/worker.sh
cp $WORKING_DIR/../../daemon/worker.sh .

docker buildx build "$WORKING_DIR" --file "$WORKING_DIR/Dockerfile" \
  --progress=plain \
  --pull \
  --build-arg BASE_IMAGE=$docker_image \
  --platform linux/$(dpkg --print-architecture) \
  -t $docker_tag
docker buildx stop
rm -rf $WORKING_DIR/worker.sh
