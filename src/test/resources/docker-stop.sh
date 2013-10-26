#!/bin/bash

CONTAINERS=`cat target/docker.containers`
DOCKER_CMD="sudo docker"

if [ ! -z "$CONTAINERS" ]; then
	for id in $CONTAINERS; do
		sudo docker stop $id
		sudo docker rm $id
	done
fi

if [ -f target/docker.imageId ]; then
	$DOCKER_CMD rmi `cat target/docker.imageId` 2>/dev/null
fi
