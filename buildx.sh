#!/usr/bin/env bash

cd "$(readlink -f "$(dirname "$0")")" || exit 9

IMAGE=postlu/pmp

EXTRA_BUILD_ARGS=()

if [[ "$GITHUB_ACTIONS" == "true" ]]
then
  EXTRA_BUILD_ARGS+=("--no-cache")
fi

case "$1" in
  push|p|--push|-p)
    PUSH_IMAGE=true
    ;;
  *)
    PUSH_IMAGE=false
    EXTRA_BUILD_ARGS+=("--load")
    ;;
esac

docker buildx build \
  --platform "linux/amd64,linux/386" \
  --output "type=image,push=${PUSH_IMAGE}" \
  "${EXTRA_BUILD_ARGS[@]}" \
  -t "$IMAGE" \
  .
