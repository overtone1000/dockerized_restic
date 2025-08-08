#!/bin/bash

set -e

REGISTRY=docker.io
UNAME=overtone1000
IMAGE_NAME=trm_restic
TAG=latest

FULLTAG=$REGISTRY/$UNAME/$IMAGE_NAME:$TAG

podman login # -u "$UNAME" $REGISTRY
podman build -t $IMAGE_NAME:$TAG ./
podman image tag $IMAGE_NAME:$TAG $FULLTAG
podman push $FULLTAG