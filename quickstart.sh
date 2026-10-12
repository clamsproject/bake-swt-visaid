#!/bin/sh
# Runs the bake-swt-visaid image on all videos in the `data` directory next to
# this script, and writes the results to the `output` directory next to it.
# Arguments are passed to the image as options (e.g., `-c fast-messy`).

image=${bake_image:-ghcr.io/clamsproject/bake-swt-visaid:latest}
name=bake-swt-visaid-$$

cd "$(dirname "$0")" || exit 1
here=$(pwd)

if ! command -v docker > /dev/null; then
    echo "The docker command is not available. Install Docker Desktop first."
    exit 1
fi
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi
if [ ! -d data ]; then
    echo "No data directory in $here. Create it and put your videos in it."
    exit 1
fi
mkdir -p config output

if ! docker pull "$image"; then
    echo "Could not download $image. Check the network connection."
    exit 1
fi

# the main process in the container ignores the interrupt signal, so a Ctrl-C
# only detaches the docker command; the trap then stops the container itself
trap 'echo "Stopping ..."; docker kill "$name" > /dev/null 2>&1; exit 130' INT TERM
docker run --rm --name "$name" --sig-proxy=false \
    -v "$here/data:/data" -v "$here/config:/config" -v "$here/output:/output" \
    "$image" "$@" .
status=$?
echo "The results are in $here/output"
exit $status
