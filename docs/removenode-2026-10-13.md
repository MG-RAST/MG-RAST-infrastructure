# DONE 2026-10-13: both dead nodes removed — ring is 14/14 clean

First time in this engagement that the cluster has **no dead members**.

| | before | after |
|---|---|---|
| ring members | 16 | **14** |
| UN | 14 | **14** |
| DN/DL | 2 | **0** |
| `UNREACHABLE` in describecluster | 2 | **0** |
| `system.peers` | 15 | 13 |

## What was run

```bash
nodetool removenode b4594e6a-30bd-4fc4-bfec-13c9d5f434ff   # bw9  / 140.221.76.75
nodetool removenode 01023d46-bbdf-482a-b69e-2905deddd30d   # bw14 / 140.221.76.82
```
Sequentially, never concurrently — Cassandra permits only one token removal at a time.

| | bw9 (.75) | bw14 (.82) |
|---|---|---|
| ranges it was a replica for | 761 (18.28% of ring) | 779 (19.13%) |
| estimated inbound | ~834 GiB | ~873 GiB |
| wall clock | ~90 min | ~124 min |
| health during | 14/14 throughout | 14/14 throughout |
| schema versions during | 1 throughout | 1 throughout |
| disk low-water | 1,243 GB | **1,135 GB** (bw16) |

No interventions were needed on either. The 300 GB floor was never approached.

## Load redistribution

Per-node load went from **811-987 GiB** to roughly **869 GiB - 1.55 TiB**, and bw16 from 1.17 to
~1.23 TiB. That growth *is* the re-replication: those ranges genuinely had only two live replicas and now
have three.

**This is the step that gave the 54,315,470 recovered rows RF=3.** For the 74 ranges where both dead
nodes had been replicas, the single survivor streamed to two new replicas — including the 3 ranges where
bw16 was the sole survivor holding the recovered data. Until this completed, that data existed in one
copy.

bw2 (.68) remains an outlier at 1.55 TiB against a ~900 GiB-1.0 TiB band. It was 1.49 TiB *before* any of
this work, so it is pre-existing and still uninvestigated.

## Monitoring pattern that worked

Poll `nodetool removenode status` until it reads `No token removals in process`, while also tracking
health keys, schema version count, and the **minimum** free space across all 14 nodes — with a hard floor
that aborts. Streaming arrives in waves rather than one batch, so a single `netstats` reading
underestimates the total; `recv=0/0.0GiB of 0/0.0GiB` plus the status line flipping is the real
completion signal.

## Next

1. **`nodetool cleanup`** on all 14 — token ranges redistributed, so each node may now hold data for
   ranges it no longer owns. Safe by construction (it only drops out-of-range data) but it rewrites
   sstables, so transient space of roughly the largest sstable is needed. Run with `-j 1`, one node at a
   time.
2. **Full repair** — the remaining step, and a separate decision: on ~4.5 TiB of unique data with no
   repair ever having run, this is a long and heavy operation.
