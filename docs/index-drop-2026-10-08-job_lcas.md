# DONE 2026-10-08: dropped the two `job_lcas` secondary indexes

First of the index drops. Measured before and after rather than asserted.

## What was run

```sql
DROP INDEX mgrast_abundance.job_lcas_ident_idx;   -- 33 s
DROP INDEX mgrast_abundance.job_lcas_len_idx;     -- 32 s
```
Issued from bio-worker7. Both timings match the earlier `job_lcas_exp_idx` canary (32 s), so a drop is a
metadata change plus file deletion — it does **not** trigger compaction.

Indexes went 5 -> 3. Remaining: `job_md5s_exp_idx`, `job_md5s_ident_idx`, `job_md5s_len_idx`.

## Verification

- **Schema converged** to a single version `f48edc7c-12c3-3b66-9558-0f3c5b1f0dfa` across all 14 live
  nodes. The `schema version mismatch detected` warning emitted by `cqlsh` during each DDL is expected —
  the two dead nodes (.75, .82) can never agree — but convergence was confirmed afterwards with
  `nodetool describecluster`, not assumed.
- **Health 14/14 `ok`** from the active probe keys in etcd.
- **Reads verified at QUORUM**, including the real production access pattern — a pinned partition with a
  range filter, which is the thing these indexes could never serve anyway:
  ```sql
  SELECT count(*) FROM mgrast_abundance.job_lcas
   WHERE version=1 AND job=1 AND ident_avg > 50 ALLOW FILTERING;   -- 1104
  ```

## Space reclaimed: ~226 GB, cross-checked two ways

Index data measured before the drop totalled **225.3 GiB** across the 14 Cassandra nodes. Summing the
per-node `df` deltas afterwards gives **226 GB**, which agrees:

| node | freed | node | freed |
|---|---|---|---|
| bw8 | +20 GB | bw13 | +18 GB |
| bw7 | +19 GB | bw15 | +18 GB |
| bw6 | +18 GB | bw4, bw5, bw10, bw12, bw17 | +17 GB each |
| bw3, bw11 | +16 GB | bw2 | +11 GB |
| bw16 | +5 GB | | |

Residual index size is 0 MB on every node. The `.job_lcas_*_idx` **directories remain but are empty** —
normal after a drop; do not mistake their presence for incomplete deletion.

bw16 moved 1,448 -> 1,453 GB free. It is still short for the rebuild; the three `job_md5s` drops are what
will free the ~674 GB it needs.

## Incidental finding: bw1 holds 1.2 TB of orphaned Cassandra data

bw1 (140.221.76.66) showed index sizes **unchanged** after the drop, which looked like a failure. It is
not: **bw1 is not a Cassandra node.** It is absent from the 16-member ring, has no `cassandra*` systemd
unit and no `cassandra-simple` container (it runs awe-server, awe-monitor, shock_nginx,
mg-rast-v4-web-dev, fleetui, confd, memcached).

Its `/media/ephemeral/cassandra-simple` is **1.2 TB of leftover data from a decommissioned instance**,
including `.job_lcas_exp_idx` (3.6 GB) from the index dropped during the canary — further confirmation
that nothing live has touched it. This explains bw1's unusually low 37% utilisation.

**Reclaimable, but confirm first.** Before deleting, verify it holds nothing unique: bw1 is not in the
ring, so it owns no token ranges and its data is by definition a stale replica — but that should be
checked against the live cluster rather than inferred, exactly as was done for bw16's `aux`.

**Note for future fleet sweeps:** the 15 SSH-reachable hosts are *not* the 14 Cassandra nodes. bw1 is in
fleet but not in the ring; bw9 (.75) and bw14 (.82) are in the ring but gone. Scripts that iterate hosts
and expect a Cassandra container will produce misleading rows for bw1.
