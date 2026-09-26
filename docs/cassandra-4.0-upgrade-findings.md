# Cassandra 3.11 -> 4.0 upgrade: tested findings

Produced 2026-09-25 on a 3-node dry-run ring on **mgrast-01** (`/local/cassandra/dryrun/`), using the
**real** `config/services/cassandra/cassandra.yaml`, the **real** `ssl.sh`, the production
`mgrast/cassandra:3.11` image, and internode TLS from a CA built to match the production CA's exact shape
(v1, no extensions, same subject DN). Nothing production was touched; mgrast-01 cannot reach the cluster.

## 1. BLOCKER: 4.0 refuses to start on the current yaml

`cassandra:4.0` exits with code 3 and **no log output beyond the exception** until six properties are
removed. All are Thrift/RPC-era and were deleted in 4.0:

```
thrift_prepared_statements_cache_size_mb
start_rpc
rpc_port
rpc_server_type
thrift_framed_transport_size_in_mb
request_scheduler
```

Cassandra reports them in two different message forms — `Those properties [...] are not valid` and
`Please remove properties [...]` — and only a few per attempt, so expect to iterate.

Safe to remove: `start_rpc` is already `false` in production, so Thrift is not in use.
Note `run_cassandra.sh` also exports `CASSANDRA_RPC_PORT` and publishes `-p 9160:9160`; both become
vestigial and should be dropped from the unit at the same time.

## 2. BLOCKER: a naive rolling upgrade SPLITS THE RING

With `internode_encryption: all`, a 3.11 node listens for internode traffic on **`ssl_storage_port`
(7002)**. Cassandra 4.0 unified internode messaging onto **`storage_port` (7000)** and deprecated
`ssl_storage_port`. Observed directly:

| node | listening |
|---|---|
| 3.11 | `:7002` |
| 4.0 (default) | `:7000` only |

Result: each side reported the other **DN**. The 3.11 nodes still saw each other UN, so the ring split
cleanly in two — the worst kind of failure, because both halves look healthy locally.

This matters here specifically because production deliberately sets `ssl_storage_port: 7002` to avoid the
etcd conflict on 7001.

**Fix (tested):** add to `server_encryption_options`:

```yaml
server_encryption_options:
    enable_legacy_ssl_storage_port: true
```

The 4.0 node then listens on **both** 7000 and 7002, and the mixed-version ring healed completely — all
three nodes UN as seen from both the 4.0 node and the 3.11 nodes.

Keep this set until every node is on 4.0, then remove it in a later pass.

## 3. Confirmed good

- **4.0.21 reads 3.11 `md-` sstables natively.** After startup and reads, all sstables on disk were still
  `md-`; 4.0 rewrote nothing. So `upgradesstables` really is deferrable.
- **Internode TLS works unchanged under 4.0** with the same `keystore.jks` / `generic-server-truststore.jks`
  produced by the existing `ssl.sh`. Zero SSL handshake errors on either side, in a mixed-version ring,
  with `require_client_auth: true`. The same-key CA renewal done 2026-09-22 carries over.
- **Data intact**: 60,000 rows readable at `QUORUM` from the 4.0 node.
- **Float secondary indexes still answer** under 4.0.

## 4. Sizing note discovered while building the ring

The `mgrast/cassandra:3.11` image **hardcodes `MAX_HEAP_SIZE="20G"` and `HEAP_NEWSIZE="800M"` in
`/etc/cassandra/cassandra-env.sh`**, which overrides the environment variable. Containers OOM-died with no
log output at all because the JVM tried to reserve 20 GB. Consequences: every production node runs a 20 GB
heap (fine on 71 GB hosts), and setting `MAX_HEAP_SIZE` in a fleet unit would be **silently ignored**.
The dry run mounts a patched `cassandra-env.sh` to cap heap at 2G.

## 5. Recommended ordering (revised by measurement)

Cluster data, measured 2026-09-25: **39.90 TiB on disk, ~13.3 TiB logical** (RF=3).
Of `mgrast_abundance`: base tables **12.41 TiB**, secondary indexes **27.38 TiB = 69%**.
The three `job_md5s` indexes are on **float** columns (`len_avg`, `ident_avg`, `exp_avg`) — near-unique
values, a known anti-pattern, and the source of the 470-575 GB sstables.

Because indexes are derived data, **drop them before `upgradesstables`, not after**:

1. `DROP INDEX` the three `job_md5s` indexes -> frees 27.4 TiB, removes the giant sstables
2. Apply the yaml changes (§1 + §2), rebuild the image, roll 3.11 -> 4.0 one node at a time
3. `upgradesstables` -> now only ~12.4 TiB to rewrite instead of 39.9 TiB

**Do NOT rebuild the indexes afterwards** - see §7, they are never consulted by any consumer. An earlier
revision of this section said to rebuild them on 4.0, which contradicted §7; that step has been removed.

## 6. Rollback: TESTED. Possible, but it is salvage - not a safety net

Exercised end to end on the dry-run ring: 3.11 -> snapshot -> 4.0 -> writes -> downgrade to 3.11.

**What 4.0 does immediately, before any `upgradesstables`:**

| | `md-` (3.11) | `nb-` (4.0) |
|---|---|---|
| `mgrast_abundance` after one flush | 6 | 3 |
| **`system` keyspace** | 16 | **17** |

4.0 rewrites most of the **system keyspace** on startup. A `nodetool snapshot <keyspace>` of user data does
**not** cover this, which is what actually blocks a downgrade.

**Downgrade attempt 1** - 3.11 on the 4.0-touched data dir, exit 3:
```
ERROR Detected unreadable sstables .../system/table_estimates-.../nb-4-big-Index.db
```
**Downgrade attempt 2** - after deleting every `nb-` file and restoring the user snapshot, exit 3 again:
```
java.lang.IllegalStateException: Unknown commitlog version 7
```
4.0's commitlog format is unreadable by 3.11 **even after a clean `nodetool drain`**. The drain flushes the
data but leaves 4.0-format commitlog files on disk.

**Downgrade attempt 3** - after also clearing `commitlog/` and `saved_caches/`: **3.11.4 started and
rejoined the ring, all nodes UN.**

### Working rollback procedure (per node)
1. `nodetool drain` then stop the 4.0 container
2. delete **every** `nb-*` file under the data dir - system keyspace included, not just user tables
3. restore user tables from the pre-upgrade snapshot
4. **clear `commitlog/` and `saved_caches/`**
5. start 3.11

### What it costs - why this is salvage, not a safety net
- **The node loses its host ID.** Original `d69eea7e-...` came back as `58ccf47a-...`. The ring accepted it
  because the IP and tokens matched, but it is effectively a new node wearing the old tokens. In production
  expect to deal with the stale host ID.
- **Data survived** - corrected 2026-09-25. An initial reading of 61,000 rows (vs 62,000 before the
  downgrade) suggested 1,000 rows were lost. That was wrong: a re-check against all three nodes
  independently returned **62,000 on every node**, with both 4.0-era partitions (`job=900`, `job=901`)
  complete. The first reading was a fragile parse plus a `CONSISTENCY ONE` read that hit the rolled-back
  node before read-repair had caught it up. Hints played no part - the hints directories were empty on all
  nodes and no handoff appears in the logs.
  **Why it survived: RF=3.** The peers still held the writes made while node1 was on 4.0, so wiping node1's
  local copy lost nothing. This is the replication factor doing exactly its job, and it is the strongest
  argument for the wipe-and-re-bootstrap recovery below rather than a downgrade.
- Every step is manual, with no dry-run safety, on a node that is already down.
- The surviving cost is therefore **the host ID, not the data** - provided RF=3 peers are healthy.

### Therefore
**Prefer rolling forward.** With RF=3 the better recovery for one bad node is to wipe it and re-bootstrap
from its peers - which works while the peers are still 3.11, but **not** across a mixed-version ring, since
streaming between major versions is unsupported. That is the real constraint to plan around: once the ring
is mixed, neither `rebuild` nor a clean downgrade is available, so the window between the first and last
node upgrade should be kept short.

Snapshots are still worth taking - they are ~2 s and hardlink-cheap - but treat them as a way to recover
*data*, not as a way to un-upgrade a node.

## 7. Secondary indexes: TESTED, and they may not be earning their 27 TiB

Measured on the dry-run ring (62,000 rows, 2 float indexes).

**Mechanics**
- `DROP INDEX` x2: **11.6 s** (mostly fixed cost at this scale). Space **is** reclaimed - the dropped
  `.job_md5s_len_idx` directory went to 0 files / 0 bytes. `auto_snapshot: true` is set in production but
  does **not** snapshot a dropped secondary index (it applies to DROP TABLE / TRUNCATE), so no hidden space
  is retained.
- `CREATE INDEX` rebuild of one index over 62,000 rows: **5 s**, producing 3.5 MB of index for a 4 MB base
  table. The rebuilt index works.

**The important finding: these indexes can only answer EQUALITY queries.**

```
SELECT ... WHERE ident_avg = 78.77      -> works, uses the index
SELECT ... WHERE ident_avg > 99.9       -> InvalidRequest: ... use ALLOW FILTERING
```

Cassandra secondary indexes do not support range predicates. `ident_avg`, `len_avg` and `exp_avg` are
**computed float averages**, so an exact-float-match lookup is almost certainly not what the application
wants - any realistic query ("identity above 90%") is a range, and a range cannot use the index at all. It
degrades to `ALLOW FILTERING`, i.e. a full scan, which is exactly what these indexes were presumably added
to avoid.

### CONFIRMED against the deployed code: the indexes are unused

Checked the running `api-server-api` container (`/MG-RAST/src/MGRAST/pylib/mgrast_cassandra.py`), the web
front end, and the load tooling.

**Every** API query against `job_md5s` is partition-key restricted:
```
SELECT <fields>      FROM job_md5s WHERE version = ? AND job = ?
SELECT seek, length  FROM job_md5s WHERE version = ? AND job = ? AND md5 = ?
```
Where the API does filter on an indexed column it uses a **range plus ALLOW FILTERING**, inside an
already-pinned partition (lines 187/193, 208/214, 242/245):
```
... WHERE version = ? AND job = ? AND ident_avg >= ? ALLOW FILTERING
```
**CORRECTION (2026-09-26).** An earlier version of this section claimed a secondary index "is not needed
once the partition is pinned". **That is wrong** - Cassandra does use a 2i inside a single partition. Proven
by `TRACING ON`:

| query shape | trace |
|---|---|
| `ident_avg = 95.5` (equality, indexed, partition pinned) | `Scanning with job_md5s_ident_idx` / `Executing read ... using index job_md5s_ident_idx` |
| `ident_avg >= 90` (range, indexed) | **`No applicable indexes found`** |
| `len_avg >= 100` (range, index dropped) | `No applicable indexes found` |

So the indexes are skipped here for exactly **one** reason: **a standard secondary index supports only
equality, not ranges**, and every API filter on these columns is `>=`. Cassandra says so itself -
"No applicable indexes found".

This matters for the risk assessment: if any consumer ever issues an **equality** query on these columns, the
index *would* be used, and dropping it would turn that into a within-partition scan (still correct, and
bounded by partition size, but slower).

**Proven empirically on the dry ring**, where `len_idx` was dropped and `ident_idx` kept:

| query | index | result |
|---|---|---|
| `... AND ident_avg >= 90 ALLOW FILTERING` | present | 400 rows |
| `... AND len_avg  >= 100 ALLOW FILTERING` | **dropped** | 500 rows |

Identical behaviour. The index contributes nothing.

**The indexes are worse than unused - they FORBID a query shape you may want.** Cassandra rejects a
secondary-index predicate combined with an `IN` on the partition key. Same query, same data, only the index
differs:

| predicate | index | result |
|---|---|---|
| `job IN (900,901) AND len_avg = 120.0 ALLOW FILTERING` | **dropped** | **3 rows** |
| `job IN (900,901) AND ident_avg = 95.5 ALLOW FILTERING` | present | `InvalidRequest: Select on indexed columns and with IN clause for the PRIMARY KEY are not supported` |

So "give me all hits across this list of jobs where <column> = x" is **illegal while the index exists** and
becomes legal once it is dropped. A cross-job *range* query
(`job IN (...) AND ident_avg >= 90 ALLOW FILTERING`) works either way - tested, 3 rows.

**The API does not support multi-job queries today**: `get_job_records(self, job, ...)` takes a single job,
and its `IN` clauses are on `md5` and on lookup tables, never on `job`. Multiple jobs are handled by looping
one query per job at the application layer.

**Other consumers:** `mgrast/v4-web` contains no reference to cassandra or `job_md5s` - it calls the API over
HTTP. The `BulkLoader` (`services/cassandra-load/`) references the columns only in CREATE TABLE and INSERT,
never as a filter.

**Origin:** `services/cassandra-load/mgrast_analysis/job_table.cql` lines 30-32 create all three `job_md5s`
indexes as part of the schema DDL (and lines 47-49 do the same for `job_lcas`). They were declared up front
for query patterns that were ultimately implemented as partition-scoped `ALLOW FILTERING` instead.

### Recommendation

**Drop all six secondary indexes and do not rebuild them.** That is 27.38 TiB on disk / ~9.1 TiB logical -
**69% of the cluster** - reclaimed, the 470-575 GB monster sstables gone, ~2 TiB freed per node, and
`upgradesstables` reduced from 39.9 TiB to ~12.4 TiB. This is worth more than everything the btrfs balances
recovered, and it is a win **independently of the 4.0 migration**.

Because rebuilding 27 TiB would be expensive if this is ever wrong, do it deliberately:
1. Drop the smallest first as a canary - `job_lcas_exp_idx` (~0.1 TiB) - and watch API behaviour and latency.
2. Then the other two `job_lcas` indexes.
3. Then the three `job_md5s` indexes, one at a time, reclaiming ~9 TiB each.

**Do NOT trust a rebuild-time extrapolation from this test.** 5 s for 62,000 rows is dominated by fixed
overhead. Scaling naively to the ~880 GB of `job_md5s` base data per production node gives absurd figures
(weeks per index), which is not credible but also cannot be ruled out. Index rebuild is a full base-table
scan, so it is not cheap. If the indexes turn out to be needed, **measure the rebuild on a realistic
dataset before committing to a maintenance window** - it may well cost more than the `upgradesstables` it
was meant to avoid.

## 8. The range queries ARE full partition scans - and production is tuned to tolerate it

Measured on the dry ring (`TRACING ON`), partition `job=1` with 1500 rows and random `ident_avg`:

| | |
|---|---|
| rows in partition | 1500 |
| rows matching `ident_avg >= 99` | **40** |
| live rows actually **read** | **3000** (1500 x 2 replicas) |

So a range filter reads the **entire partition** and discards ~97% of it. Correctness is fine; cost is
bounded by partition size rather than table size.

**Production partition sizes make that expensive** (`nodetool tablehistograms mgrast_abundance job_md5s`):

| percentile | partition size | cells |
|---|---|---|
| 50% | 219 KB | 17,084 |
| 75% | 8.4 MB | 654,949 |
| 95% | 108 MB | 7,007,506 |
| 99% | **224 MB** | **17,436,917** |
| max | **387 MB** | **30,130,992** |

The median partition is harmless. But a p99 query scans **17.4 million cells**, and the worst partition
**30 million**, to return a subset.

**The configuration already admits this.** Every relevant timeout in `run_cassandra.sh` is **10x the
Cassandra default**, with the defaults left in the comments:

```
read_request_timeout_in_ms   = 50000    # default 5000
range_request_timeout_in_ms  = 100000   # default 10000
request_timeout_in_ms        = 100000   # default 10000
slow_query_log_timeout_in_ms = 5000     # default 500
compaction_large_partition_warning_threshold_mb = 256   # default 100
```

That is the fingerprint of exactly this problem: the cluster was tuned to *tolerate* full-partition scans
instead of avoiding them. Note `slow_query_log_timeout_in_ms = 5000` means nothing is logged as a slow query
until it exceeds 5 seconds, so the slowness is largely invisible in the logs.

**The secondary indexes were the attempted fix and they cannot work**, because a standard 2i serves only
equality while every one of these filters is a range. Dropping them costs nothing in query capability.

**What would actually fix it** is a data-model change - putting the filtered attribute into the clustering
key, e.g. `PRIMARY KEY ((version, job), ident_avg, md5)`, which turns `ident_avg >= x` into an efficient
clustering slice with no scan. That is a schema change plus a reload of 4.1 TiB logical, so it is a separate
project from the 4.0 upgrade - but it is the real answer, and the 4.0 migration is a natural moment to
consider it since the data is being rewritten anyway.

## 9. Independent review (2026-09-26): drop is sound, but for sharper reasons

Reviewed against the resource constraints. Verdict: **sound with caveats**. Corrections and additions:

### The indexes are a standing disk-full risk TODAY - drop sooner, not later
Index sstables of 470-575 GB under STCS: the next tier merge wants >=4 of them, i.e. ~2 TiB free. bw8 has
925 GiB. Cassandra will keep shrinking the candidate set ("Not enough space for compaction, reducing scope")
until it fits, so **the index CFS on the tight nodes is effectively permanently un-compactable** - tombstones
never purge and sstable count only grows. Combined with `disk_failure_policy: stop`, that is a live
ENOSPC-to-node-death path, and it is also why `upgradesstables` is impossible on bw8 while the indexes exist
(a pre-upgrade snapshot pins 2.5 TiB of index files, and rewriting a 575 GB sstable needs 575 GB free).
**Keeping them is the more dangerous state.**

### Rebuild: plan as irreversible, but not because of disk or heap
My per-node arithmetic (dropping frees what a rebuild consumes) is right at steady state, and heap is **not**
a blocker (3.11 index builds are paged; 20 GB CMS will give ugly GC pauses, not OOM). The real blockers:
- **`concurrent_compactors` unset with one data dir resolves to 2** in 3.11. An index build occupies one of
  those two threads for its entire duration.
- **Transient STCS space**: expect a further ~0.5-1 TiB per node late in the build, on top of the steady-state
  figure - which puts bw8/bw6/bw13 at or below today's already-marginal headroom.
- **Time**: per node per index, a full read of ~0.85 TiB of base data plus ~2-3 TiB of compaction writes at
  16 MB/s is on the order of **2 days per index**; three indexes require three separate full base scans
  (`CREATE INDEX` cannot batch them). Order of magnitude: **one to two weeks of degraded cluster**, all 14
  nodes at once, page cache thrashed, API reads slow throughout.
- **Non-resumable**: a node restart mid-build restarts that node's build from zero. The mandatory cert-driven
  rolling restart makes that concrete.
- **No observability**: no metrics, `slow_query_log_timeout_in_ms` at 5000, so this would run blind.

**Verdict: achievable in principle, not achievable by this team at acceptable risk. Treat the drop as a
one-way door** - which is acceptable, because the only capability behind that door is global equality lookup
on a computed float average, which no consumer needs and which is scientifically meaningless.

### Dropping also makes streaming ~3x cheaper - a benefit not previously stated
2i cost on every path, not just SELECT: writes fan out to three index memtables, base compaction runs an
index cleanup transaction, and **every sstable received by streaming is index-built on receipt**. So
`removenode` of the two dead ring members, any repair, and any wipe-and-re-bootstrap recovery all get
dramatically cheaper once the indexes are gone. That directly shortens recovery inside the mixed-version
upgrade window.

### Canary must test the REBUILD, not just the drop
The operator's fear is the rebuild, so the canary has to measure it: **drop `job_lcas_exp_idx` (~7-8 GiB per
node), wait, `CREATE INDEX` it back and measure per-node wall time, `compactionstats` progress, GC warnings
and API latency, then drop it again.** That converts the rebuild cost from a fear into a number. Scale by
rows not bytes (job_lcas partitions are much smaller than job_md5s) and treat the extrapolation as
optimistic. Use `cqlsh --request-timeout=300` for every schema statement - a timed-out DROP may still have
applied, so check `system_schema.indexes` rather than retrying blindly.

### Middle options: all rejected
- Keep one of three on `job_md5s`: retains ~640 GiB per node and the un-compactable monster CFS, buys only
  float-equality on one column. Reject.
- Snapshot before drop: `nodetool snapshot` hardlinks the index CFS too, so it reclaims **nothing** while it
  exists, and restoring an index from snapshot files means hand-editing `system.IndexInfo`. Not a real option.
- Nothing cheaper preserves optionality; optionality and free space are in direct opposition here.

### The schema redesign is NOT advisable now, and my proposed key was wrong
`PRIMARY KEY ((version, job), ident_avg, md5)` **breaks the point lookup** `WHERE version=? AND job=? AND
md5=?` that the API uses to fetch `seek, length`. So the original table must stay: **minimum 2x base storage**
(~25 TiB on disk) for one filtered attribute, and three attributes as three clustered copies would be ~37 TiB
- more than the indexes just removed. Only one clustering column can be sliced; the other two stay as
within-slice filtering.

Worse, **selectivity is an unverified premise**. The 40/1500 example is synthetic. MG-RAST's default
evalue/identity/length cutoffs may pass almost every hit, in which case the "scan" *is* the result set and no
key change helps at all. That cannot be measured today. **Fix observability first** - lower
`slow_query_log_timeout_in_ms` from 5000 toward 500 at the next restart - then decide with data.
SASI (experimental, disabled by default in 4.0, OOM-prone on large partitions) and materialized views (a full
extra copy, experimental) are both rejected. If data ever justifies it, the cheapest route is a quantised
clustering column (`ident_bin int`) in a **new** table, dual-written for new jobs and backfilled per job by a
resumable script - after the drop and after 4.0.

### Ring health: bw16 is under-replicated
bw16 holds **332 GiB of base data against 907-966 GiB** on peers - roughly a third, with 256 vnodes and RF=3
where ownership should be even. Its index footprint is low for the same reason (679 GiB vs ~2.1 TiB), so this
is missing **data**, not broken indexes. No index build is running on any node. **The ring has had two dead
token owners for years and needs a repair before any major upgrade.**

### Never run a schema change in the mixed-version window
3.11<->4.0 schema propagation is explicitly the thing not to exercise. All DROP INDEX work must complete
before the first node is upgraded.

### Recommended order
1. Disable the `CREATE INDEX` statements in `job_table.cql` (done) and fix this document (done).
2. Verify the real index list in `system_schema.indexes`; investigate bw16's deficit.
3. Canary: drop + rebuild + drop `job_lcas_exp_idx` to get a measured rebuild rate.
4. Drop the remaining five, `job_md5s` one at a time, 24-48 h apart, watching API latency.
5. Cert-driven rolling restart (already mandatory) - doubles as validation that nodes start clean without the
   index CFS. No `CREATE INDEX` running during it.
6. `nodetool removenode` .75/.82 - after the drop (smaller streams, no index build on receipt), before the
   upgrade (must not be mixed-version).
7. Repair (`-pr`, per node) so the ring is genuinely healthy before a major upgrade.
8. Snapshot, roll 3.11 -> 4.0 quickly (§1 and §2 fixes), then `upgradesstables`, then clear snapshots.

### Smaller corrections
- `exp_avg` is an e-value exponent, so the API filter is probably `<=` rather than `>=`. Still a range;
  conclusion unaffected.
- The IN-clause + index restriction is verified on **3.11 only**; assume but do not claim it for 4.0.
- Per-node figures in this document are **GiB**, not GB.
- At production scale a `DROP INDEX` returns in seconds but btrfs unlinks 500 GB files asynchronously, so
  `df` may lag by minutes. Do not panic if space does not appear immediately.
- `BulkLoader.sh` runs at `-Xmx20G` alongside Cassandra's fixed 20 GB heap - 40 of 71 GB - relevant only if a
  co-located reload is ever attempted.

## 10. Not yet tested
- `upgradesstables` behaviour and timing on realistic data shapes.
- API driver/protocol compatibility against 4.0.
- Full-ring upgrade completion and removal of `enable_legacy_ssl_storage_port`.
