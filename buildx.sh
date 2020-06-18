#!/usr/bin/env bash

cd "$(readlink -f "$(dirname "$0")")" || exit 9

get_latest_version() {
  local url="https://www.manageengine.com/products/passwordmanagerpro/download-free.html"

  curl -fsSL "$url" | \
    sed -nr "s/.*The latest PMP version is (.+) \(Build ([0-9]+)\).+/\1 \2/p"
}

IMAGE=postlu/pmp

EXTRA_BUILD_ARGS=()

if [[ "$GITHUB_ACTIONS" == "true" ]]
then
  EXTRA_BUILD_ARGS+=("--no-cache")
fi

case "$1" in
  push|p|--push|-p)
    EXTRA_BUILD_ARGS+=("--push")
    ;;
  *)
    EXTRA_BUILD_ARGS+=("--load")
    ;;
esac

read -r version build <<< "$(get_latest_version)"

if [[ -z "$version" ]] || [[ -z "$build" ]]
then
  echo "Failed to determine version and/or build" >&2
  exit 6
fi

echo "Building image for PMP version $version - build: $build"

docker buildx build \
  --platform "linux/amd64,linux/386" \
  "${EXTRA_BUILD_ARGS[@]}" \
  -t "${IMAGE}:${version}-${build}" \
  -t "${IMAGE}:build-${build}" \
  -t "${IMAGE}:${version}" \
  -t "${IMAGE}:latest" \
  .
