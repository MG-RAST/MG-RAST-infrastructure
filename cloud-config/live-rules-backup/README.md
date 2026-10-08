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

## 2026-10-08: mgrast-01 added

The upstream network conduit for mgrast-01 was opened (ticket to CELS systems). mgrast-01 can now
initiate SSH to the bio-workers; verified with a real login from mgrast-01:

```
$ ssh core@140.221.76.73 hostname -f
bio-worker7-10g.mcs.anl.gov
```

The conduit is **one-directional**. A bio-worker still cannot reach `140.221.31.93:22` or `:873`
outbound, so any data movement must be **pulled from mgrast-01**; do not design a push-from-node
step or an rsync daemon.

Each node needs this host-level allowlist entry, which must sit **before** the catch-all DROP:

```
-A INPUT -p tcp -s 140.221.31.93 --dport 22 -j ACCEPT -m comment --comment "mgrast-01"
```

Live insert (note `-I INPUT 1`, not append — appending lands it after the DROP and is inert):

```
sudo iptables -I INPUT 1 -p tcp -s 140.221.31.93 --dport 22 -m comment --comment 'mgrast-01' -j ACCEPT
```

Persist by inserting the same line into `/var/lib/iptables/rules-save` before its DROP line.
That file is loaded by `iptables-restore.service` at boot and is hand-maintained (filter table only,
no Docker chains) — do **not** regenerate it with a bare `iptables-save`, which would capture
Docker's chains.

**Diagnosing whether a block is ours or upstream.** Do not infer it from other ports: the upstream ACL
is default-deny with a port-22-only conduit, so `9042`/`4001`/`7199` are blocked even from the
workstation despite the hosts' own INPUT chain dropping **only** port 22. The reliable method is the
per-rule packet counter plus a capture:

```
sudo iptables -L INPUT -n -v --line-numbers | head -3      # pkts on the ACCEPT rule
sudo tcpdump -nni any 'host 140.221.31.93 and tcp port 22' -c 20 -t
```

A completed handshake is SYN / SYN-ACK / ACK and roughly 5 packets / 268 bytes on the counter — which
is easy to misread as SYN retransmissions. Read the capture, not the counter alone.
