
## Linux

```bash
wget https://github.com/coreos/fleet/releases/download/v0.11.5/fleet-v0.11.5-linux-amd64.tar.gz
tar xvzf fleet-v0.11.5-linux-amd64.tar.gz
cp fleet-v0.11.5-linux-amd64/fleetctl /usr/local/bin/
```

## OSX

```bash
brew update & brew install fleetctl
```

## Configure .bashrc (Linux and OSX)

```bash
export FLEETCTL_TUNNEL=<ip address of one coreos instance>
```