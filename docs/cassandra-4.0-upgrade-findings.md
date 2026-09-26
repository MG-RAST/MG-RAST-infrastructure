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
4. Rebuild the indexes on 4.0 (generated natively in the new format)

Doing it the other way round means paying to format-convert 27 TiB of derived data and then discarding it.
Worth asking at step 4 whether float-column indexes should be recreated at all.

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
A secondary index cannot serve a range, and is not needed once the partition is pinned - Cassandra just
filters within it, which is bounded and cheap.

**Proven empirically on the dry ring**, where `len_idx` was dropped and `ident_idx` kept:

| query | index | result |
|---|---|---|
| `... AND ident_avg >= 90 ALLOW FILTERING` | present | 400 rows |
| `... AND len_avg  >= 100 ALLOW FILTERING` | **dropped** | 500 rows |

Identical behaviour. The index contributes nothing.

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

## 8. Not yet tested
- `upgradesstables` behaviour and timing on realistic data shapes.
- API driver/protocol compatibility against 4.0.
- Full-ring upgrade completion and removal of `enable_legacy_ssl_storage_port`.
