#!/bin/bash

# delete all unused images
docker rmi `docker images | awk '{ print $3; }'`