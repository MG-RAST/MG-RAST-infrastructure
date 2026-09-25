# Cassandra health monitoring

Three layers, all added 2026-09-25. Before this, the cluster had no Cassandra
monitoring at all: `cadvisor`, `ganglia-gmond`, `mgrast-checkres` and `log-courier`
have unit files here but none are loaded in fleet, `opscenter@` is archived, and the
running Elasticsearch is the metagenome search backend (newest index 2018) with zero
log-shaped indices.

## Why it exists

`cassandra-simple-discovery@` writes its etcd key **unconditionally**, so it only ever
proves the *unit* is alive. On 2026-09-22 bw6 was found reporting `UN` with gossip
active while its Cassandra had logged nothing for 2.5 months and would not service a
JMX request — `nodetool drain` hung for over 12 minutes. Nothing noticed.
**`nodetool status` is not a liveness check.**

## 1. Probe (on each node)

`config/services/cassandra/health_probe.sh` in the private config repo. Checks the
container is running, **JMX answers**, gossip + native transport are active, and a real
CQL read succeeds (`SELECT release_version FROM system.local` — tiny, always present,
node-local, so no cluster load). Every step wrapped in `timeout`, so the probe cannot
hang the way `nodetool` did.

## 2. Publisher (fleet, per node)

`fleet-units/cassandra-simple-health@.service` runs the probe every 45s and publishes
to `/services/cassandra-simple/health/cassandra-simple@N` with a 150s TTL.
`MachineOf=cassandra-simple@%i`. Three distinguishable states:

| etcd key | meaning |
|---|---|
| `ok <ip> <epoch>` | node genuinely serving |
| `fail:<reason> <ip> <epoch>` | probe ran, node is sick |
| absent | the health unit itself is dead/unscheduled |

Start with `fleetctl submit cassandra-simple-health@.service` then
`fleetctl start cassandra-simple-health@N.service` for each N.

NOTE: `%` is a systemd specifier. `date +%s` must be written `date +%%s` in a unit
file or systemd substitutes the user's shell and the timestamp is silently garbage.

## 3. Operator + alerting

- `scripts/cassandra_health.sh` — run on any cluster host. Cross-references health keys
  against the registered instance list, so a node whose health unit never started shows
  as `MISSING` rather than silently missing from the report. Exit 0 only if all ok.
- `scripts/cassandra_health_alert.sh` — run from an **operator workstation** via cron.
  Mails on state change only (plus a reminder every 6h while broken); silent while
  healthy, and deliberately silent on a first run against a healthy cluster.

Alerting lives off-cluster on purpose: SMTP is unreachable from the bio-workers (25 and
587 both closed), and a monitor inside the system it watches cannot report that the
system failed.

### The restricted ssh key

Cron cannot use the passphrase-protected operator keys. The alerter therefore uses a
dedicated passphrase-less key restricted to a single forced command — a read-only etcd
GET. It cannot obtain a shell, a pty, or run anything else (verified: arbitrary commands
are ignored, PTY allocation refused). See
`scripts/cassandra-health-alerter.authorized_keys` for the exact line.

Install on a node with:

    update-ssh-keys -a cassandra-health < cassandra-health-alerter.authorized_keys

**Durability gap:** `update-ssh-keys` writes to `~core/.ssh/authorized_keys.d/`, which
survives reboots but **NOT a PXE reprovision**, because CoreOS regenerates
`authorized_keys` from the cloud-config `ssh_authorized_keys` block. To make it durable,
add the same line to the `ssh_authorized_keys` source used by
`cloud-config/update_cloud_config_pxe.sh` (it reads `~/git/mgrast-config/`, which was not
available on the workstation where this was set up) and regenerate the PXE cloud-config.
Until then, a reprovisioned node loses the key and the alerter reports it via the normal
`UNREACHABLE`/`MISSING` path rather than failing silently.

## Deliberately NOT used: log-line staleness

A healthy but idle node legitimately logs nothing for many hours — bw6 was measured at
15h of silence while answering CQL in 4.4s. Staleness alone false-positives. Active
probing distinguishes idle from wedged. Keep log staleness only as a secondary signal
with a threshold in days.
