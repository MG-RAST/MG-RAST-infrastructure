# bw16 rebuild: result, and CONFIRMED production data loss recoverable only from aux

2026-10-09/10. Supersedes the verification section of `RUNBOOK-bw16-rebuild.md`.

## The rebuild worked

| | before | after |
|---|---|---|
| load | 333.84 GiB | **1.17 TiB** |
| `job_md5s` sstables | — | 23 (peaked at 212; peer bw7 has 36) |
| pending compactions | 11 | 0 |
| disk | 2,125 GB free / 61% | ~1,300 GB free / 77% |
| health probe | ok | ok, uninterrupted |

Streaming: **874.1 GiB in 482 files over ~8 h** (~30 MB/s against a 400 Mb/s ceiling), from all live
replicas. Compaction then ran ~9 h after `setcompactionthroughput 64` cut the estimate from 6h00m to
1h29m per pass. Schema stayed at one version across all 14 nodes; bw16 never left `UN`. Disk low-water
was 1,099 GB against a 350 GB floor.

`nodetool cleanup -j 1 mgrast_abundance` returned **exit 0 in 5 s with no work**, so bw16 holds no
out-of-range data. Its ~190-360 GiB excess over the 811-987 GiB peer band is therefore **genuine data for
ranges it owns** — bw16 is now the most complete node in the ring, which suggests the peers are short
(no full repair has ever run). bw2 (.68) at 1.49 TiB is a separate, pre-existing outlier.

## Two verification methods that DO NOT work — do not repeat these

**1. "Oldest sstable predates 2021-07" is meaningless.** This was proposed as *the* proof and it is
worthless: streamed sstables are newly written files carrying **today's** mtime. A file timestamp records
when the file was created, not the age of the data inside. After the rebuild bw16's oldest sstable reads
`2021-09-17`, which says nothing either way.

**2. `nodetool getendpoints` is broken for composite partition keys.** It returned the **identical**
replica set for five different keys, across two different tables:
```
1:174229 -> 140.221.76.73 140.221.76.75 140.221.76.12
1:126570 -> 140.221.76.73 140.221.76.75 140.221.76.12   (same, and so on)
```
Any per-replica comparison built on it is void. Use `token()` + `nodetool describering` instead.

## Working method: exact replica resolution via describering

```bash
ssh core@140.221.76.73 'sudo docker exec cassandra-simple nodetool describering mgrast_abundance' > describering.txt
```
then parse `start_token`/`end_token`/`endpoints` and test wrap-around with
`inrange = (s<e) ? (t>s && t<=e) : (t>s || t<=e)`. Parsing all 4,096 ranges accounts for
**100.0000%** of the ring, which validates it.

### Exact exposure from the two dead nodes

| | ranges | % of ring |
|---|---|---|
| **both** .75 and .82 as replicas -> only ONE live copy | **74** | **1.9338%** |
| ...of which **bw16 is the sole survivor** | **3** | **0.1151%** |
| exactly one dead replica (QUORUM still works) | 1,392 | 33.5399% |
| fully on live nodes | 2,630 | 64.5262% |

Sole-survivorship is spread across all 14 nodes (2-9 ranges each); bw16's 3 is unremarkable in count. It
matters only because bw16 is the one node whose single copy has known gaps.

The three ranges where bw16 is the only live replica:
```
( 2673230211064149878,  2681044053612720098]   0.04236%
(-6478142121595927340, -6475740758970911495]   0.01302%
(-5994071617074692823, -5983049077543464690]   0.05975%
```

**The rebuild structurally could not fix these.** `rebuild` streams *from other replicas*; where bw16 is
the only live replica there is no source. Confirmed empirically below.

## CONFIRMED DATA LOSS — and aux is the only source

Scanning those ranges in the aux instance and comparing against production at **`CONSISTENCY ONE`**
(QUORUM is unsatisfiable for these ranges by definition — it fails `Unavailable` rather than returning 0):

| token range | aux rows | production rows | short by |
|---|---|---|---|
| `( 2673230211064149878, …098]` | 0 | 59,377 | — (all post-2021) |
| `(-6478142121595927340, …495]` | 88,127 | 38,400 | **49,727** |
| `(-5994071617074692823, …690]` | 308,623 | 111,890 | **196,733** |

Per job: of **152** `job_lcas` jobs in those ranges, **142 return zero rows in production** while aux
holds their data — counts from 1 to 11,405 rows each. Ten match (post-2021 data bw16 retained).

**~246,000 rows of `job_lcas` are missing from production and exist only in aux.** Had aux been deleted
to free disk space, this would have been permanent and silent.

Caveats, stated honestly:
- `aux - production` is an approximation, not a set difference: the first range shows production holding
  59,377 rows aux does not have (post-2021 writes), so the relationship is not pure subset. A row-level
  diff is needed for an exact recovery set.
- Job 490784 reports production = **exactly 5000** against aux 7839. The round number is suspicious
  (cqlsh's default page size is 5000) and `count(*)` truncation has not been ruled out. Treat that one
  figure as unverified.
- **`job_md5s` has not been scanned at all.** It is the large table (1.2 TB on bw16 vs 6.5 GB for
  `job_lcas`), so its gap in the same ranges is likely far larger. Scanning it needs the 693 GiB
  `job_md5s` copy loaded into the aux instance.

## Consequences

1. **Do not `removenode` .75/.82 until this is loaded.** Afterwards those ranges are reassigned and
   stream from bw16, so QUORUM starts succeeding while silently serving the incomplete copy — the loss
   becomes invisible and unrecoverable.
2. **`job_md5s` must be scanned the same way** before any conclusion about total exposure.
3. The 71 ranges whose sole survivor is a long-lived node are presumed intact, but that is an assumption,
   not a measurement. A full repair after `removenode` remains the right closing step.
4. Keep `cassandra-simple-aux` on bw16. It is not redundant with the mgrast-01 backup — it is the second
   copy of the only source of this data.
