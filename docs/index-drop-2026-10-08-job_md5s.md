# DONE 2026-10-08: all five secondary indexes dropped — 27.06 TiB reclaimed

`mgrast_abundance` now has **zero** secondary indexes (`system_schema.indexes` returns 0 rows).

## What was run

| index | DDL elapsed | schema version after |
|---|---|---|
| `job_lcas_ident_idx` | 33 s | `f48edc7c-12c3-3b66-9558-0f3c5b1f0dfa` |
| `job_lcas_len_idx` | 32 s | (same batch) |
| `job_md5s_ident_idx` | 11 s | `f72ec024-dfd6-3e76-800f-354d6704050d` |
| `job_md5s_len_idx` | 35 s | `8e4692f7-8e8e-3ec5-bd6d-d082994ec93c` |
| `job_md5s_exp_idx` | 33 s | `d6e800e8-9bb9-3fa0-a7da-4f340fe46630` |

Schema convergence to a **single** version across all 14 live nodes was confirmed with
`nodetool describecluster` after each drop. The `schema version mismatch detected` warning cqlsh prints
during every DDL is just the two dead nodes (.75, .82), which can never agree.

## Two traps worth knowing

**1. `OperationTimedOut` does not mean the drop failed.** The first `job_md5s` drop returned
`OperationTimedOut: Client request timeout` after 11 s — that is cqlsh's **10 s client default**, not
server failure. The drop had in fact succeeded: schema converged and the index was gone from
`system_schema.indexes`. Pass `--request-timeout=120` to avoid the misleading error.

**2. File deletion is asynchronous and lags the DDL by minutes.** After the `job_md5s_ident_idx` DDL
returned, 13 of 14 nodes showed 0 residual within a minute, but **bw16 still held 215 GiB** and had
freed only 6 GB. It completed on its own some minutes later. Do not conclude a drop failed from a
non-zero residual immediately after the DDL — poll until it reaches zero.

## Space reclaimed: 27.06 TiB, cross-checked two ways

Index data measured before: **27.06 TiB** (`ident` 9.18, `len` 9.35, `exp` 8.54). Sum of per-node `df`
deltas afterwards: **27,708 GiB = 27.06 TiB**. The two agree.

| node | before | after | | node | before | after |
|---|---|---|---|---|---|---|
| bw8 | 954 GB / 83% | **3438 GB / 37%** | | bw2 | 1888 / 65% | 3157 / 42% |
| bw6 | 1049 / 81% | **3154 / 42%** | | bw3 | 1237 / 78% | 3209 / 41% |
| bw13 | 1171 / 79% | 3303 / 39% | | bw7 | 1672 / 69% | 3965 / 27% |
| bw16 | 1453 / 74% | **2125 / 61%** | | bw17 | 2129 / 61% | 4207 / 22% |

Cluster utilisation went from 60–83% to **22–61%**. Residual 0 MB on all 14 nodes. The
`.job_md5s_*_idx` and `.job_lcas_*_idx` directories remain but are empty — normal after a drop.

## Proof the indexes were unused

The same production-shaped query, run immediately before the second `job_md5s` drop and again after all
five were gone:

```sql
CONSISTENCY QUORUM;
SELECT count(*) FROM mgrast_abundance.job_md5s
 WHERE version=1 AND job=222227 AND ident_avg > 80 ALLOW FILTERING;
```
**466 rows before, 466 rows after.** Identical. This is the direct confirmation of the earlier tracing
result (`No applicable indexes found`): every API filter is a *range* predicate and Cassandra 2i serve
equality only, so these indexes consumed 69% of the cluster while answering nothing.

Health throughout: **14/14 `ok`** from the active probe.

## Immediate consequence for the bw16 rebuild

bw16 now has **2,125 GB free** against the ~652 GiB the rebuild needs — roughly 3x headroom, so
`cassandra-simple-aux` never has to be deleted.

**But `Device unallocated` on bw16 is still 707.88 GiB, exactly where it was before 688 GB of index data
was removed.** This is the btrfs behaviour documented in `RUNBOOK-bw16-rebuild.md`: deleting files
returns space to `df` but not to the unallocated pool that new *metadata* chunks come from. Run
`btrfs balance start -dusage=50 --background /media/ephemeral` on bw16 **before** the rebuild. bw8 is the
next lowest at 954.88 GiB unallocated.
