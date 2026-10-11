# Recovery load plan — ready to execute, blocked on write permission

2026-10-11. Supersedes the row counts in `bw16-rebuild-result-and-data-gap.md`, which were wrong.

## THREE CORRECTIONS to earlier numbers

**1. The at-risk job set is 273, not 152.** `SELECT DISTINCT version, job WHERE token(...) > X AND <= Y`
returned 152 jobs and was **silently truncated**. The authoritative enumeration is the `COPY TO` export
itself, which walks the token ranges directly: **273 distinct jobs** in `job_md5s`, 267 in `job_lcas`.
121 jobs were missing from every downstream analysis. **Do not trust `SELECT DISTINCT` over a token range
on a large table** — cross-check against an export.

**2. The row count is ~54M, not ~7.74M.** Measured by export:

| file | rows | distinct jobs | size |
|---|---|---|---|
| `job_md5s_r2.csv` | 10,867,765 | 52 | 781M |
| `job_md5s_r3.csv` | 43,050,955 | 221 | 3.1G |
| `job_lcas_r2.csv` | 88,127 | 52 | 15M |
| `job_lcas_r3.csv` | 308,623 | 215 | 51M |
| **job_md5s total** | **53,918,720** | **273** | |

The earlier ">=7,738,561" came from 133 single-partition `count(*)` queries; the 13 that timed out were
precisely the giant partitions (largest is job 472199 at **3,217,858** rows). A floor derived by dropping
the measurements that failed *because the values were large* understates badly — that should have been
treated as a signal, not a footnote.

**3. Production's existing rows for these jobs are degraded, not merely sparse.** For job 239170, where
counts matched at 122, the values agree on `md5`/`abundance`/`exp_avg`/`ident_avg`/`len_avg` but
production has **`null` for `length` and `seek`** while aux has real values. Normal jobs outside these
ranges *do* have them populated (e.g. job 174229: `length=256, seek=0`). `seek`/`length` are the file
offsets used to retrieve sequence data, so those rows cannot serve sequence lookups.

Consequence: loading aux is strictly an improvement — it adds missing rows **and** repairs null
`length`/`seek` — and regresses nothing, since the other columns agree where both have data.

## The gate is CLEAR

`JobDB` on bio-worker19 (140.221.76.65), via `docker exec`:

| | |
|---|---|
| at-risk jobs found in `JobDB` | **273 of 273** |
| `viewable = 1` | **all 273** |
| `public = 1` | **57** |
| `public = NULL` / `0` | 214 / 2 |

**No job in the recovery set was deleted**, so there is no zombie risk. 57 are public metagenomes;
spot-checked live via the API: `mgm4447449.3` ("WT4", job 7279), `mgm4463044.3`, `mgm4463513.3`.

Cluster totals for reference: **512,891 jobs** in `JobDB`, of which **82,836 public** (16%), 4,212
private, 425,843 unset. Cassandra holds ~427,400 (`job_lcas`) / ~437,500 (`job_md5s`) distinct jobs, so
**~75-85k jobs have no abundance data at all** — a separate question worth investigating.

## Writes MUST use CONSISTENCY ONE

Proven, not assumed:
```
CONSISTENCY QUORUM; SELECT job ... WHERE version=1 AND job=22641  ->  NoHostAvailable
CONSISTENCY ONE;    SELECT job ... WHERE version=1 AND job=22641  ->  (0 rows)
```
These partitions have one live replica, so QUORUM cannot be satisfied in either direction. The `ONE` read
returning 0 rows also independently confirms genuine absence rather than unreadability.

`HELP COPY_FROM` does not exist in this cqlsh build, so whether `COPY FROM` honours the session
consistency level is **unverified** — which is exactly why the trial below must be run and checked first.

## Execute

Export files live in the `aux-test` container on mgrast-01 at `/tmp/exp/`. The backup remains
`chmod -R a-w`; all of this was produced from the third, disposable copy.

### Step 1 — trial on one small job (68 rows), and VERIFY

```bash
# stage
scp 140.221.31.93:/tmp/trial.csv /tmp/trial.csv
scp /tmp/trial.csv core@140.221.76.73:/tmp/trial.csv
ssh core@140.221.76.73 'sudo docker cp /tmp/trial.csv cassandra-simple:/tmp/trial.csv'

# before: expect 0
ssh core@140.221.76.73 'sudo docker exec cassandra-simple cqlsh --cqlshrc=/tmp/q.rc \
  -e "CONSISTENCY ONE; SELECT count(*) FROM mgrast_abundance.job_md5s WHERE version=1 AND job=360317;"'

# load
ssh core@140.221.76.73 'sudo docker exec cassandra-simple cqlsh --cqlshrc=/tmp/q.rc --request-timeout=300 -e "
CONSISTENCY ONE;
COPY mgrast_abundance.job_md5s (version, job, md5, abundance, exp_avg, ident_avg, len_avg, length, seek)
  FROM '"'"'/tmp/trial.csv'"'"' WITH HEADER=TRUE;"'

# after: expect 68, and length/seek must be non-null
ssh core@140.221.76.73 'sudo docker exec cassandra-simple cqlsh --cqlshrc=/tmp/q.rc -e "
CONSISTENCY ONE;
SELECT count(*) FROM mgrast_abundance.job_md5s WHERE version=1 AND job=360317;
SELECT md5, length, seek FROM mgrast_abundance.job_md5s WHERE version=1 AND job=360317 LIMIT 3;"'
```

**Do not proceed past this unless the count is exactly 68 and `length`/`seek` are populated.** If `COPY
FROM` ignores the session consistency it will fail with `Unavailable`/`NoHostAvailable` here, which is the
whole point of trialling it.

### Step 2 — full load, smallest files first

`job_lcas` first (396,750 rows, 66M) because it is small and failures are cheap; then `job_md5s`
(53.9M rows, 3.9G). Use `WITH HEADER=TRUE AND MAXBATCHSIZE=20 AND INGESTRATE=5000` to stay gentle, and
check free disk on the receiving nodes between files.

### Step 3 — verify per job, then the ranges

Re-run the range-scoped comparison from `bw16-rebuild-result-and-data-gap.md`, but per job via the
batched `cqlsh -f` pattern, comparing against the per-job counts in the container at `/tmp/per_job.txt`.
Only after that: `removenode` the two dead nodes, `nodetool cleanup`, then a full repair.
