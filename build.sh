#!/usr/bin/env bash

cd "$(readlink -f "$(dirname "$0")")" || exit 9

IMAGE=postlu/pmp

docker build -t "$IMAGE" .

case "$1" in
  push|p|--push|-p)
    docker push "$IMAGE"
    ;;
esac
