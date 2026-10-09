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
