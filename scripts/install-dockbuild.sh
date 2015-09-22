#!/bin/bash
set -x

rm -f /home/core/dockbuild
docker pull mgrast/dockbuild
docker rm -f dockbuild
docker create --name dockbuild mgrast/dockbuild
docker cp dockbuild:/app/dockbuild /home/core/
docker rm -f dockbuild