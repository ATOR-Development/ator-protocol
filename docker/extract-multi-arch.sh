#!/bin/bash

#
# Script allows to build ator-protocol binaries for different linux architectures using docker
#

set -o errexit

ATOR_PLATFORMS="${ATOR_PLATFORMS:-linux/arm64,linux/amd64}"
ATOR_BUILD_DIR="${ATOR_BUILD_DIR:-build}"

if [ ! -f 'Dockerfile' ]; then
    echo "Dockerfile not found"
    exit 1
fi

# Build images for specified platforms
docker buildx build -f Dockerfile --platform $ATOR_PLATFORMS -t ator-protocol .

IFS=', ' read -r -a platforms <<< "$ATOR_PLATFORMS"

# Extract binaries from each platform
for platform in "${platforms[@]}"
do
    echo "[$platform] Extracting binaries"

    mkdir -p $ATOR_BUILD_DIR/$platform/

    echo "[$platform] Creating container"
    CONTAINER=`docker create ator-protocol --platform $platform --name ator-build-container`

    echo "[$platform] Copying binaries"
    docker cp $CONTAINER:/usr/local/bin/tor $ATOR_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/tor-gencert $ATOR_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/tor-print-ed-signing-cert $ATOR_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/tor-resolve $ATOR_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/torify $ATOR_BUILD_DIR/$platform/

    echo "[$platform] Removing container"
    docker rm -v $CONTAINER
done
