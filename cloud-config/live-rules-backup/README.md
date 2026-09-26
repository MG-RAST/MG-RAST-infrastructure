# Live firewall rules backup — captured 2026-09-26

`INPUT-ssh-allowlist.live-2026-09-26.rules` is the human-authored portion of the INPUT chain, captured from
`sudo iptables-save` on bio-worker7 and **verified byte-identical across all 14 nodes** (Docker's own
per-container rules were excluded; those legitimately differ per host).

## Why this backup exists: the live rules DO NOT match the PXE template

`cloud-config/cloud-config-pxe.yaml.template` (lines ~126-130) writes this allowlist:

```
-A INPUT -p tcp -s 192.5.200.126 --dport 22 -j ACCEPT   # warehouse13
-A INPUT -p tcp -s 140.221.6.203 --dport 22 -j ACCEPT   # pamby
-A INPUT -p tcp -s 140.221.9.203 --dport 22 -j ACCEPT   # namby
-A INPUT -p tcp -s 140.221.76.2  --dport 22 -j ACCEPT   # bio-infra1
-A INPUT -p tcp -s 0.0.0.0/0     --dport 22 -j DROP
```

The live nodes additionally allow, and these are **NOT in the template**:

```
-A INPUT -s 140.221.27.0/24 --dport 22 ACCEPT   # Homes-Network
-A INPUT -s 140.221.27.9/32 --dport 22 ACCEPT   # Homes
-A INPUT -s 140.221.76.0/24 --dport 22 ACCEPT   # bio-worker (supersedes 140.221.76.2)
```

**`140.221.27.9` is the operator workstation.** So a PXE reprovision using this template would come back
with **no SSH access from the workstation** — you would need console or a host on one of the remaining
allowlisted networks to recover it.

## Caveat

`cloud-config/update_cloud_config_pxe.sh` builds the real PXE config from `~/git/MG-RAST-infrastructure/`
and `~/git/mgrast-config/`, **not** from this checkout. Neither was present on the workstation where this was
captured, so it is possible the template actually used for PXE already carries the extra rules and only this
checkout's copy is stale. **Reconcile before the next reprovision** — this is the same `~/git/mgrast-config`
dependency that blocks making the monitoring ssh key durable (see `scripts/README-cassandra-health.md`).

## Restore

```
sudo iptables-restore --noflush < INPUT-ssh-allowlist.live-2026-09-26.rules
```
Order matters: the catch-all DROP must remain last in the chain. Check with `sudo iptables -S INPUT` first.
