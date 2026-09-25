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

## 6. Not yet tested

- Rollback: snapshot -> upgrade -> attempt downgrade to 3.11 -> restore. A `pre-upgrade` snapshot was taken
  (2 s, hardlinks) but the downgrade path has not been exercised.
- `upgradesstables` behaviour and timing on realistic data shapes.
- API driver/protocol compatibility against 4.0.
- Full-ring upgrade completion and removal of `enable_legacy_ssl_storage_port`.
