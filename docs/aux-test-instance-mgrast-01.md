# Standalone 3.11 instance over the bw16 aux backup (mgrast-01)

Purpose: read the pre-2021 data out of bw16's `cassandra-simple-aux` **without** touching production, so
the recovery gap can be measured and specific job partitions extracted. See
`RUNBOOK-bw16-rebuild.md` for how this fits the sequence.

## Status 2026-10-08: fully staged, blocked on host memory

Everything is built and verified except the final start, which the host cannot currently satisfy — see
"Why it will not start yet" below. A watcher is armed to start it automatically once memory frees.

Location: `mgrast-01:/local/cassandra/aux-test/`

## Design decisions worth keeping

**Real copy, not hardlinks.** Hardlinking the backup's sstables would have been instant and free, and
sstables are immutable so Cassandra would never corrupt them. But the container runs as uid 999 and
`chown` acts on the **inode**, which hardlinks share — so chowning the test copy would have silently
changed the ownership of the pristine backup. A real copy avoids that entirely. Only 6.6 GB was copied
(`system`, `system_schema`, `job_lcas`, `job_info`); `job_md5s` (693 GiB) is deliberately left for later.

**Use the aux `system_schema`, not a fresh CREATE TABLE.** The table directories carry their original
UUIDs (`job_md5s-d8bd4410961911e6ae7529ff21047bb5`). A freshly created table gets a *new* UUID and would
not match, so the sstables would be invisible. Copying aux's own `system_schema` brings the 2021 schema
including the original table IDs. Copying aux's `system` likewise preserves the old tokens and host id —
and since a single node owns the whole ring regardless, all the data is readable.

**`cluster_name` must match or it refuses to start.** aux's `system.local` says
`MG-RAST Cluster simple`, so the yaml says the same.

**Isolation, three layers.** `--network none` (no interfaces but loopback, so it physically cannot gossip),
`system.peers` deleted from the copy so it knows no cluster members, and `listen_address`/`rpc_address` at
127.0.0.1. Independently, mgrast-01 cannot reach 7000/7002 on the bio-workers at all — the conduit is
port 22 only — so even a misconfigured instance could not join production.

## Four traps hit while building it, all with fixes

1. **`sudo` on mgrast-01 requires a tty**, unlike the bio-workers, so `sudo chown` over ssh fails with
   `you must have a tty to run sudo`. Do the chown in a root container instead, which needs no host sudo:
   ```bash
   docker run --rm -v /local/cassandra/aux-test:/t --user 0 --entrypoint chown \
     mgrast/cassandra:3.11 -R 999:999 /t
   ```
   Note this also chowns `conf/`, so hand that back to the host user (uid 3581) afterwards or you can no
   longer edit the config from the host.
2. **Do not mount the config files `:ro`.** The image's `docker-entrypoint.sh` chowns `/etc/cassandra/*`
   and dies with `Read-only file system`.
3. **`--network none` breaks the entrypoint and then the JVM.** The entrypoint calls
   `hostname --ip-address` when the address env vars are `auto`; set
   `CASSANDRA_LISTEN_ADDRESS`/`BROADCAST_ADDRESS`/`RPC_ADDRESS` explicitly to skip it. Cassandra itself
   then fails with `Local host name unknown: java.net.UnknownHostException: auxtest`, because docker does
   not add the hostname to `/etc/hosts` on a `none` network — fix with
   `--hostname auxtest --add-host auxtest:127.0.0.1`.
4. **`MAX_HEAP_SIZE="20G"` is hardcoded at line 164 of the image's `cassandra-env.sh`**, with
   `HEAP_NEWSIZE="800M"`, and it overrides the environment variables. Patch the file; setting
   `-e MAX_HEAP_SIZE` alone does nothing.

Also: **the image's logback sets the ROOT logger to `WARN`**, so `Starting listening for CQL clients` and
every other INFO milestone never appears. Do not wait on those strings — poll `nodetool info` instead.

## Why it will not start yet

mgrast-01 is not idle. Two `freyja` processes hold **18.5 GB RSS each (37 GB)**, and the commit budget is
already exhausted:

```
CommitLimit:    35,009,116 kB   (33.4 GiB)
Committed_AS:   56,732,456 kB   (54.1 GiB)   <- 20 GiB over
```

Cassandra dies at startup with `Native memory allocation (mmap) failed to map 12288 bytes`. This is not a
heap-sizing problem: it reproduces at 12G, 4G, 2G and 1G heaps, and with thread pools cut to
`concurrent_reads/writes: 8`, `concurrent_compactors: 1`, `memtable_flush_writers: 1`. A trivial
`java -Xmx256m -version` in the same image starts fine, so it is Cassandra's larger virtual reservations
being refused, not a broken JVM or a thread limit (`threads-max` 513314, 2338 threads in use).

**Do not pass `--ulimit memlock=-1`** here. It makes Cassandra's `mlockall(MCL_CURRENT|MCL_FUTURE)`
succeed, which then requires every subsequent allocation to be physically backed — actively worse when
RAM is tight. Leaving memlock restricted produces a harmless `Unable to lock JVM memory (ENOMEM)` warning.

**`freyja` was left running.** It is an external workload, plausibly the wastewater/lineage pipeline, and
not ours to kill.

Also stopped three idle dry-run containers (`cdry1_rb2`, `cdry2`, `cdry3`) left from the 2026-09-25
exercise, reclaiming ~5 GB. Reversible with `docker start`.

## Starting it

```bash
bash /local/cassandra/auxtest_when_free.sh     # waits for the budget, starts, then verifies
```
It polls `/proc/meminfo` until `Committed_AS < CommitLimit` (or freyja exits), starts the container, waits
for JMX, then prints `nodetool info`, the keyspace list from the 2021 schema, and a real read out of the
aux sstables.

---

# WORKING 2026-10-09 — and the real blocker was not memory

## Root cause: 48,860 sstables in aux's system keyspaces

The repeated `Native memory allocation (mmap) failed to map N bytes` was **map-area exhaustion, not RAM**:

| keyspace in the aux copy | files | `Data.db` |
|---|---|---|
| `system` | 185,184 | **23,148** |
| `system_schema` | 205,696 | **25,712** |
| `mgrast_abundance` | 96 | 12 |

391,016 files total. Cassandra mmaps each sstable's data/index/summary at startup, blowing straight
through `vm.max_map_count = 65530`. That is why it failed identically at 12G, 4G, 2G and 1G heaps, with
minimal thread pools, and still failed once `Committed_AS` had dropped well below `CommitLimit` with 51 GB
available. The memory pressure from `freyja` was real but **incidental** — it sent me down the wrong path
for several attempts.

The old bw16 had tens of thousands of never-compacted system sstables. That is a pathology in its own
right and may be related to why it was re-provisioned in 2021.

## The fix: fresh system keyspaces, schema created explicitly, sstables refreshed in

Do **not** reuse aux's `system`/`system_schema`. Instead:

```bash
# 1. start with an EMPTY data dir so Cassandra builds its own system keyspaces
# 2. create the schema by hand (from production DESCRIBE TABLE)
docker exec aux-test bash -c 'printf "[connection]\nhostname = 127.0.0.1\nport = 9042\n" > /tmp/q.rc'
docker exec aux-test cqlsh --cqlshrc=/tmp/q.rc -e "
CREATE KEYSPACE IF NOT EXISTS mgrast_abundance WITH replication =
  {'class': 'SimpleStrategy', 'replication_factor': 1};
CREATE TABLE IF NOT EXISTS mgrast_abundance.job_lcas (
    version int, job int, lca text, abundance int, exp_avg float,
    ident_avg float, len_avg float, level int, md5s int,
    PRIMARY KEY ((version, job), lca)
) WITH CLUSTERING ORDER BY (lca ASC);"

# 3. copy the aux sstables INTO the new table dir -- it has a NEW uuid
#    (aux: job_lcas-e5c4d650...  new: job_lcas-fcff8b00...), top-level files only,
#    no .job_lcas_*_idx subdirs and no snapshots
# 4. chown 999:999, then:
docker exec aux-test nodetool refresh mgrast_abundance job_lcas
```

This trades the "table UUIDs must match" problem for a `nodetool refresh`, which is the better deal.

Two more traps: the image's **shipped `cqlshrc` enables SSL and points at a certfile that does not
exist**, so cqlsh fails with `IOError(2, 'No such file or directory')` — write a fresh one, exactly as
`config/services/cassandra/health_probe.sh` does. And `sudo` needs a tty on mgrast-01, so the copy and
chown must run in a `--user 0` container; note the tree is owned by 999, so host-side `mkdir` fails.

## Verified working

```
nodetool status  ->  UN 127.0.0.1  Load 4.88 GiB  256 tokens  owns 100.0%
```
All 64 `job_lcas` sstables are **`md` generation** — 3.11-native and 4.0-readable, so no generation
problem for a later recovery. Partition enumeration works: `SELECT DISTINCT version, job ... LIMIT 15`
returns immediately.

### First real comparison: aux vs production, and all 15 sampled jobs match

| job | aux rows | production rows | | job | aux | prod |
|---|---|---|---|---|---|---|
| 174229 | 460 | 460 | | 126570 | 6271 | 6271 |
| 290677 | 1859 | 1859 | | 6298 | 1074 | 1074 |
| 173159 | 63 | 63 | | 299681 | 2277 | 2277 |
| 233561 | 885 | 885 | | 416230 | 387 | 387 |
| 197475 | 55 | 55 | | 20600 | 180 | 180 |
| 26046 | 176 | 176 | | 78130 | 124 | 124 |
| 94500 | 606 | 606 | | 167226 | 58 | 58 |
| 386560 | 264 | 264 | | | | |

**Do not over-read this.** The at-risk fraction is only ~1% of bw16's ranges, so a 15-job sample has
roughly a 0.99^15 ≈ 86% chance of containing no at-risk job at all. "All match" is the *expected* result
whether or not gaps exist. It validates the method, not the absence of gaps.

## IMPORTANT correction to the gap-measurement plan

The plan said: query the live cluster per job and collect the ones returning **zero rows**. That is wrong
for the ranges that actually matter.

For a range whose replica set was {bw16, bw9, bw14}, only bw16 is up — so a **QUORUM read cannot be
satisfied at all** and fails with `Unavailable`/timeout. It does **not** return `count = 0`.

So the gap scan must:

1. Read at **`CONSISTENCY ONE`** to get whatever survives, and compare the count against the aux instance.
   A zero or short count then means a genuine gap.
2. Treat an **`Unavailable` at QUORUM** as its own signal — that *is* the "two replicas dead" set, and it
   is the population to compare against aux first.

Both must happen **before `removenode`**, because afterwards those ranges are reassigned and stream from
bw16, so QUORUM starts succeeding while silently serving incomplete data — the failure becomes invisible.
