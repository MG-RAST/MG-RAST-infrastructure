# bw1's orphaned Cassandra data: ~3,900 more recoverable jobs

Investigated 2026-10-12. **Corrects an earlier suggestion that this 1.2 TB was simply reclaimable disk.**
It is not — it is the only known source for thousands of jobs.

## What it is

bio-worker1 (140.221.76.66) is **not** a Cassandra node — absent from the 16-member ring, no `cassandra*`
unit, no container. It runs awe-server, awe-monitor, shock_nginx, mg-rast-v4-web-dev, fleetui, confd,
memcached. But `/media/ephemeral/cassandra-simple` holds **1.2 TB** of data from when it *was* a ring
member.

| | |
|---|---|
| sstable dates | **2017-06-06 → 2017-10-02** |
| generation | all **`mc`** (3.0/3.x era — not `md`) |
| `Data.db` files | 2,564 |
| `job_md5s` | 1.2 TB total, of which **845 GB is the three secondary indexes** -> ~355 GB base |
| `job_lcas` | 14 GB |
| `job_info` | 3.9 MB, 3 sstables |
| also present | `m5nr_v1` 6.6 GB, `system` 32 MB, `system_schema` 55 MB, a `mgrast-config` checkout |

So bw1 served until roughly **October 2017** and was then stopped, not decommissioned — its data was
never streamed elsewhere.

## Reading it offline, cheaply

No instance needed. `job_info` is tiny and `sstabledump` works standalone, using the serialization
header embedded in the sstable. bw1 has `mgrast/cassandra:3.10` cached locally, which is the native
version for `mc`:

```bash
D=$(sudo ls -d /media/ephemeral/cassandra-simple/data/mgrast_abundance/job_info-* | head -1)
sudo docker run --rm -v $D:/d:ro --entrypoint sstabledump mgrast/cassandra:3.10 /d/mc-72-big-Data.db
```
Partition keys come out as `"key" : [ "1", "<job>" ]`, so the full job list is a grep away. Do **not**
pull `mgrast/cassandra:3.11` for this — 3.10 is already there and reads `mc` natively.

## What it contains

**51,076 distinct jobs**, ids 3 … 331,107, with real `job_info` values (`loaded=true`, md5s/lcas counts,
timestamps from Sept 2017).

**171 of the 273 at-risk jobs we just recovered from aux were also here** — so bw1 was an independent
second source for most of that recovery. Useful redundancy, now moot.

**More importantly, it holds jobs production does not.** Of 250 sampled bw1 jobs outside the at-risk set:

| | |
|---|---|
| present in production `job_md5s` | 230 |
| **absent from production** | **20 (8%)** |
| of those 20, still in `JobDB` with `viewable=1` | **19** (2 public, 17 private/unset) |
| not in `JobDB` at all (deleted) | 1 |

Extrapolating 8% across its 50,905 other jobs: **~4,000 jobs absent from production, of which ~95% are
still expected — roughly 3,900 recoverable jobs.** Sampled examples span 2012-2014 (job 65801 =
`mgm4498168.3`, 120084 = `mgm4552451.3`).

That is **more than ten times** the 273 jobs recovered from aux, though a different failure mode: these
are plausibly the residue of bw1 being stopped without a decommission, compounded by the later loss of
bw9 (.75) and bw14 (.82) which would have held the other replicas.

## Consequences

1. **DO NOT delete bw1's `/media/ephemeral/cassandra-simple`.** An earlier note called it reclaimable
   disk. That was wrong — it is the only known source for ~3,900 jobs' abundance data.
2. The recovery method is already proven: `sstabledump` or a standalone instance over a **copy**,
   `COPY TO` with token bounds, `JobDB` gate, then `COPY FROM` at the right consistency. Same discipline:
   never run an instance against the only copy.
3. Caveat not yet investigated: bw1's data is the **2017** state. If any of those jobs were reprocessed
   later, bw1's rows may be stale — but where production has nothing, stale-and-present beats absent.
   Worth checking a few against `JobDB.Job.created_on` / pipeline version before a bulk load.
4. The 8% figure is from a 250-job sample. Confirm against the full 50,905 before committing to a plan.
