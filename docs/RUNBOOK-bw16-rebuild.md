# RUNBOOK: rebuild bio-worker16 (140.221.76.12)

Queued 2026-10-08. All numbers below are measured on the live cluster, not estimated.

## Why

bw16 owns a full 256-token share but carries **1,010.91 GiB** against peers' **2.74-3.40 TiB**. It was
re-provisioned around April 2021, rejoined owning its whole range, and its history was never streamed
back. `removenode` of the two dead nodes streams from surviving replicas, so **bw16 must be rebuilt
first** or the "restored" replicas inherit its gaps.

## Measured state

| | bw7 (healthy peer) | bw16 | deficit |
|---|---|---|---|
| `job_md5s` base data | ~960 GiB | ~329 GiB | ~630 GiB |
| `job_md5s` indexes (ident/len/exp) | 2,295 GiB | 674 GiB | 1,621 GiB |
| `job_lcas` base + 2 indexes | 25 GiB | 7.1 GiB | ~18 GiB |
| **total load** | **~3.2 TiB** | **~1,010 GiB** | **~2.23 TiB** |

bw16 filesystem: 5.26 TiB total, **1.41 TiB free**, 707.88 GiB btrfs-unallocated.

## BLOCKER and why the order matters

A rebuild today would need **~2.23 TiB** of inbound streaming into **1.41 TiB** of free space. It does
not fit.

But **~1.62 TiB of that deficit is secondary-index data that we are about to drop** (the five indexes are
proven unused — every API filter is a range query and Cassandra 2i serve equality only). So:

**Drop the indexes first.** This frees 679 GiB on bw16 *and* shrinks the rebuild to **~652 GiB** of
base-table data — a 3.5x reduction — and removes any need to touch `cassandra-simple-aux`.

Correct order:

1. Drop `job_lcas_ident_idx`, `job_lcas_len_idx` (small, ~5 GiB on bw16 / ~19 GiB per peer)
2. Drop the three `job_md5s` indexes, one at a time, 24-48 h apart
3. **`nodetool rebuild` on bw16** (this runbook) — now ~652 GiB
4. `removenode` of bio-worker9 (.75) and bio-worker14 (.82)
5. Full repair — a separate decision; weeks of cluster-wide load

## Do NOT free space by deleting cassandra-simple-aux

`/media/ephemeral/cassandra-simple-aux` is **2.6 TiB** and exists on bw16 only (five peers checked, none
have it). It is the pre-reprovision data directory: 49,518 `*-Data.db` spanning 2016-10-12 to 2021-04-09.
Ranges whose replica set was {bw16, bw9, bw14} may have **no other surviving copy** — and those two
nodes are gone for good: ICMP down, SSH closed, `generation:0 heartbeat:0 TOKENS: not present` in gossip,
absent from fleet, and still pinned at the superseded schema `44bb01fe-...` in `system.peers` while the
14 live nodes are on `2248d57a-...`.

**But only ~745 GiB of the 2.6 TiB is irreplaceable.** Measured breakdown:

| inside aux | size | keep? |
|---|---|---|
| `job_md5s` base data | **~737 GiB** | **yes** |
| `job_md5s` `.job_md5s_{len,ident,exp}_idx` | 1,735 GiB | no — derived, and being dropped anyway |
| `job_md5s` snapshots | 88 GiB | no |
| `job_lcas` base | ~5 GiB | yes |
| `job_lcas` indexes + snapshots | 31 GiB | no |
| `job_info` | 20 MiB | yes |
| `system` + `system_schema` | 1.7 GiB | yes — old token/schema provenance |
| `m5nr_v1`, `m5nr_v12` | 26 GiB | no — reference DBs, reloadable |

So the backup is **~745 GiB, ~2.3 h**, using 0.8 TB of mgrast-01's 5.8 TB:

```bash
ssh 140.221.31.93 'mkdir -p /local/cassandra/bw16-aux && nohup rsync -rlptD --no-o --no-g \
  --partial --bwlimit=60000 --info=stats2 \
  --rsync-path="sudo rsync" \
  --exclude="snapshots/" --exclude=".job_md5s_*_idx/" --exclude=".job_lcas_*_idx/" \
  --exclude="m5nr_v1/" --exclude="m5nr_v12/" \
  core@140.221.76.12:/media/ephemeral/cassandra-simple-aux/ /local/cassandra/bw16-aux/ \
  > /local/cassandra/bw16-aux-rsync.log 2>&1 &'
```
`--rsync-path="sudo rsync"` because parts of the tree are root-owned; `--no-o --no-g` because the
receiving side is unprivileged; `--bwlimit=60000` to keep read I/O off a live node's back; `--partial`
so a 2.3 h transfer is resumable.

**Second route to the space.** Deleting aux's index directories and snapshots alone frees **1.82 TiB**
without touching any base data, taking bw16 from 1.41 TiB to ~3.2 TiB free — enough for the full
2.23 TiB rebuild even without dropping the live indexes first. Those are derived data and the same
indexes are being dropped cluster-wide regardless, so this is low-risk; still, do the base-data backup
above before any deletion.

## Disk safety — the real risk is compaction, not the inbound volume

`disk_failure_policy: stop` halts the node on a full disk, so this gets its own section.

Streamed sstables arrive as **new** files and are then compacted against the existing ones by STCS, so
transient demand is roughly the sum of a compaction's inputs — not the net data gained. Measured
sstable sizes (base data, index subdirs excluded):

| | bw16 | bw7 (healthy peer) |
|---|---|---|
| largest | 146.4 GiB | **541.3 GiB** |
| next three | 87.6 / 54.7 / 34.4 GiB | 74.7 / 49.7 / 41.7 GiB |
| count | 19 | |

As bw16 converges on peer shape it will grow sstables of that order, so plan for a compaction with
several hundred GiB of inputs.

**Free space by stage.** The two space-freeing steps already ahead of the rebuild are what make it safe:

| stage | bw16 free | inbound needed | verdict |
|---|---|---|---|
| today | 1.41 TiB | 2.23 TiB | **impossible** |
| after deleting aux indexes + snapshots (+1.82 TiB) | ~3.23 TiB | 2.23 TiB | thin |
| after also dropping the 5 live indexes (+679 GiB) | **~3.9 TiB** | **652 GiB** | ~6x headroom |

Do not start the rebuild before both. Then:

1. **`btrfs balance` after the deletes.** Freeing files does *not* return `Device unallocated` — bw16 is
   at 707.88 GiB unallocated against 4.57 TiB allocated. New *metadata* chunks come only from
   unallocated space, which is the route to btrfs ENOSPC while `df` still looks fine. Judge from
   `btrfs filesystem usage`, never `df`:
   ```bash
   ssh core@140.221.76.12 "sudo btrfs balance start -dusage=50 --background /media/ephemeral"
   ssh core@140.221.76.12 "sudo btrfs balance status /media/ephemeral"
   ```
   Budget ~1 h per 350 chunks (~6 chunks/min observed).

2. **Rebuild in bounded token slices.** 3.11 `nodetool rebuild` accepts `-ks` and `-ts`, so the inbound
   volume per step is capped and the work is resumable:
   ```bash
   ssh core@140.221.76.12 "sudo docker exec cassandra-simple nodetool rebuild \
     -ks mgrast_abundance -ts '(start_token,end_token]' datacenter1"
   ```
   Get the ranges from `nodetool ring`. Between slices: let compaction settle
   (`nodetool compactionstats`), re-check free space, then continue. Slice sizing of ~100 GiB inbound
   keeps the worst-case compaction well inside headroom.

3. **Do not `disableautocompaction` to save space.** It defers the cost into one larger compaction later,
   which is the failure mode you are trying to avoid.

4. **Arm a hard-stop watch on free space** for the duration, because the node will not warn you:
   ```bash
   while true; do
     ssh core@140.221.76.12 "df --output=pcent /media/ephemeral | tail -1" 
     sleep 300
   done
   ```
   If it crosses ~90%, stop streaming (restart the container — there is no `nodetool stop STREAM` for
   rebuild in 3.11), let compaction drain, reassess. Streamed-but-uncompacted sstables are not lost;
   rebuild is additive and re-runnable.

## Preconditions (verify each before starting)

```bash
N=140.221.76.12
X="sudo docker exec cassandra-simple"

# ring is 14 UN / 2 DN and ONE schema version
ssh core@$N "$X nodetool status; $X nodetool describecluster"

# free space exceeds the expected inbound volume with margin
ssh core@$N "df -h /media/ephemeral; sudo btrfs filesystem usage /media/ephemeral | grep unallocated"

# available_ranges MUST be empty, else rebuild silently skips ranges it
# believes it already holds. Verified empty 2026-10-08.
ssh core@$N "$X bash -c \"printf '[connection]\nhostname = $N\nport = 9042\n' > /tmp/q.rc; \
  cqlsh --cqlshrc=/tmp/q.rc -e 'SELECT * FROM system.available_ranges LIMIT 5;'\""
```
The shipped `cqlshrc` enables SSL while `client_encryption_options` is disabled server-side, hence the
fresh `/tmp/q.rc` (same trick as `health_probe.sh`).

## Run

`nodetool rebuild` streams every range the node owns from other replicas. Single DC, so the source DC is
`datacenter1`. It is **additive** — it does not delete, so it is safe to interrupt and re-run.

```bash
# raise stream throughput deliberately; default is 200 Mb/s = ~25 MB/s
ssh core@140.221.76.12 "sudo docker exec cassandra-simple nodetool setstreamthroughput 400"

# detached, so losing the ssh session does not kill it
ssh core@140.221.76.12 "sudo docker exec -d cassandra-simple nodetool rebuild datacenter1"
```

Monitor:

```bash
watch -n 60 'ssh core@140.221.76.12 "sudo docker exec cassandra-simple nodetool netstats | head -40"'
ssh core@140.221.76.12 "sudo docker exec cassandra-simple nodetool compactionstats"
ssh core@140.221.76.12 "df -h /media/ephemeral"
```

At 400 Mb/s (~50 MB/s) on the 10 g fabric, 652 GiB is roughly 4 h plus compaction. `compaction_throughput_mb_per_sec`
is 16, so post-stream compaction is the long tail — raise it with `nodetool setcompactionthroughput` only
while the node has headroom, since `disk_failure_policy: stop` halts the node on a full disk.

## Verify

```bash
# load should approach peer values
ssh core@140.221.76.73 "sudo docker exec cassandra-simple nodetool status | grep -E '76.12|76.73'"

# oldest sstable on bw16 should now predate 2021-07
ssh core@140.221.76.12 "sudo find /media/ephemeral/cassandra-simple/data/mgrast_abundance -name '*-Data.db' -printf '%T+\n' | sort | head -1"
```
The sstable-age check is the real proof: the pre-2021 history is the thing that was missing.

## If it goes wrong

Rebuild is additive and resumable; re-running is safe. If bw16 approaches full, stop the stream
(`nodetool stop STREAM` does not exist — restart the container) and reassess. Do not run rebuild
concurrently with an index drop or a `removenode`.

## Caveats

- Keep the health monitor in view throughout: `scripts/cassandra_health.sh`. A node can be UN while
  wedged (bw6, 2.5 months), so ring status alone is not liveness.
- bw9 (.75) and bw14 (.82) are ICMP-down and SSH-closed, so `removenode` is the only option for them,
  never `decommission`.
