#!/bin/bash
set -x

rm -f /home/core/dockbuild
docker pull mgrast/dockbuild
docker rm dockbuild
docker create --name dockbuild dockbuild
docker cp dockbuild:/app/dockbuild /home/core/
