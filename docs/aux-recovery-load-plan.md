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

---

# DONE 2026-10-11/12 — 54,315,470 rows recovered, 0 skipped

| table | rows imported | time | skipped |
|---|---|---|---|
| `job_lcas` r2 | 88,127 | 5.7 s | 0 |
| `job_lcas` r3 | 308,623 | 16.0 s | 0 |
| `job_md5s` r2 | 10,867,765 | 9 m 04 s | 0 |
| `job_md5s` r3 | 43,050,955 | 35 m 53 s | 0 |
| **total** | **54,315,470** | ~46 min | **0** |

All at `CONSISTENCY ONE`. `COPY FROM` **does** honour the session consistency level — verified by the
trial succeeding where QUORUM returns `NoHostAvailable`. That was the one unverified assumption.

## Verification

**`job_lcas`, by range** — the after-counts correctly exceed aux's own totals, because production held
post-2021 rows aux lacks, so the result is the union:

| range | before | aux | after | union check |
|---|---|---|---|---|
| …911495 | 38,400 | 88,127 | **120,274** | 88,127 + 32,147 = 120,274 |
| …464690 | 111,890 | 308,623 | **390,831** | 308,623 + 82,208 = 390,831 |

**`job_md5s`, per job** (range-scoped `count(*)` is unusable on this table — it exceeds
`range_request_timeout_in_ms`):

| job | before | after | aux |
|---|---|---|---|
| 7279 (public, "WT4") | 15,000 (truncated) | **76,791** | 76,791 |
| 124039 | 10,000 (truncated) | **1,163,162** | 1,163,162 |
| 100560 | 4,519 (truncated) | **5,163** | 5,163 |
| 125892 | absent | **247** | 247 |
| 329293 | absent | **15,724** | 15,724 |
| 183631 | absent | **199,889** | 199,889 |
| 472199 (largest) | absent | **3,217,858** | 3,217,858 |

Cluster throughout and after: 14 UN, one schema version, **0 dropped mutations**, 14/14 health probes
`ok`, 0 pending compactions, bw16 1.17 TiB load / 1.3 T free.

## Transport note

The 4.08 GB of CSV went **mgrast-01 -> bw7 directly over the conduit at 111 MB/s** (~89% of 1 GbE line
rate), skipping the workstation. First production use of the firewall opening.

## Two process lessons

**A silently mangled command looked like success.** The first `job_lcas` attempt produced no output and
no error, because the filename quoting through `ssh -> docker exec -> cqlsh -e` was malformed. It was
caught only by re-checking the range counts and seeing them unchanged. Fix: put the CQL in a file and run
`cqlsh -f`. Never infer success from the absence of an error through a multi-layer quoting chain.

**Verify by re-measuring the thing itself.** Every check above is a before/after count against an
independent source, not an inspection of the tool's own report. `0 skipped` from `COPY FROM` was
necessary but not sufficient.

## STILL OUTSTANDING — the recovered data is single-copy

These partitions have **one live replica**. Everything just recovered exists in exactly one copy, on
bw16, at RF=1 in practice. Until the sequence below completes, a bw16 failure loses it again:

1. `removenode` bio-worker9 (.75) and bio-worker14 (.82)
2. `nodetool cleanup`
3. **full repair** — this is what actually restores RF=3 for these ranges

**Do not delete `cassandra-simple-aux` on bw16, and keep the mgrast-01 backup `chmod -R a-w`, until the
repair has completed and been verified.**

---

# INCOMPLETE: `job_info` was never repaired

The row data is restored, but `mgrast_abundance.job_info` — the per-job index — is still empty for these
jobs. It was overlooked: the aux test instance was only ever given `job_lcas` and `job_md5s`, so
`job_info` (6.4 MB in the backup) was never loaded or examined.

```
job_info ((version, job)) -> updated_on, md5s int, lcas int, loaded boolean
```

On a healthy job the values are accurate — job 174229 reads `md5s=2467, lcas=460, loaded=True`, matching
its real row counts exactly. For the at-risk jobs the partition exists but **every column is null**:

| | |
|---|---|
| at-risk jobs with a `job_info` row | 271 of 273 |
| rows with all columns null | **271** |
| rows with `loaded = True` | **0** |

**Whether this blocks the API is unresolved.** `/profile/<mgm>` is asynchronous; a submission for the
restored job 7279 (`mgm4447449.3`) was still `processing` with `rows: 0` after ten polls over ~3 minutes,
and the untouched control behaves the same way, so the test distinguishes nothing. Do not assume either
way.

**Repair cannot be a copy from aux.** Aux's counts are the 2021 values, but production now holds the
union of aux's rows and post-2021 rows that aux never had — the `job_lcas` ranges went to 120,274 and
390,831 against aux's 88,127 and 308,623. So the correct `md5s`/`lcas` values must be **counted from
production after the load**, per job, then written with `loaded = true` and a current `updated_on`.
Single-partition `count(*)` works but is slow on the large partitions (job 472199 at 3.2M rows needed a
550 s timeout), so budget for a long pass.

Note the loader's own contract, from `services/cassandra-load/BulkLoader/BulkLoader.java`: `job_info`
takes `version, job, updated_on, md5s, lcas, loaded`, where `updated_on` is **text** in the loader's
schema but `timestamp` in the live table.
