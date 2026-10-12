# `/profile` never completes: a fork() deadlock in the API, plus Python 2 code on Python 3.9

Diagnosed 2026-10-12. **Not Cassandra. Not missing data.** Unrelated to the bw16/aux recovery — it
predates it. Two independently fatal bugs in the same code path, both producing the identical symptom.

## Symptom

`GET /profile/<mgm>` returns `{"status":"submitted", "url": .../profile/status/<uuid>}`. Polling that URL
returns `status: processing, rows: 0` **forever** — nothing ever times out or reports failure.

## Bug 1: forking a process with live cassandra-driver threads deadlocks the child

The forked child blocks on its **first** Python call, before touching Cassandra or Shock.

Evidence — `docker top api-server-api` across the four API hosts:

| host | stuck `api.cgi` children |
|---|---|
| 140.221.76.77 | 268 |
| 140.221.76.11 | 257 |
| 140.221.76.69 | 247 |
| 140.221.76.68 | 268 |
| **total** | **1,040** |

All 268 on .77 verified exhaustively (not sampled): `Threads: 1`, blocked in **syscall 202 (futex)**,
`utime=0 stime=0` — never consumed a single CPU tick — kernel stack
`futex_wait_queue_me -> futex_wait -> do_futex -> SyS_futex`. Oldest `etimes` ≈ **129 days**, i.e. since
the containers started on 2026-05-19. `SCRIPT_URL` breakdown: **247 `/profile`, 17 `/matrix`, 4 versioned**
— nothing else. `/proc/<pid>/environ` shows hundreds of *distinct* mgm ids across all formats and
sources, so it is **not data-specific**.

Caught live: a direct `curl` to `127.0.0.1:32769/profile/...` produced child pid 9246 — `State: S`,
`Threads: 1`, `utime=0 stime=0`, `syscall: 202`, and open fds were **only** the inherited sockets plus a
pipe: **no socket to 9042 and none to Shock.** The parent is `Sl` (multi-threaded), the child `S` — the
driver's Python threads do not survive `fork()`.

Reproduced in a read-only harness mimicking `profile.pm`: create a Cassandra handle (leaving driver
threads alive), `fork()`, child does `py_eval('from profile import Profile')` -> **deadlocked 14/15,
0 successes**. Control with no live driver threads (`CassTest` only, which calls `cluster.shutdown()`) ->
child exits cleanly, no deadlock.

## Bug 2: Python 2 code on a Python 3.9 interpreter

`Inline::Python` 0.57 links `libpython3.9.so.1.0`, and there is **no Python 2 in the image at all**. But
`/MG-RAST/site/lib/pylib/shock.py:13` is `import cStringIO` (Python 2 only), with `urllib.quote` at
lines 16/55.

| pylib module | imports under the interpreter the API actually uses |
|---|---|
| `cass_connection.py`, `mgrast_cassandra.py`, `m5nr.py` | OK |
| `shock.py` | **FAIL** — `No module named 'cStringIO'` |
| `profile.py`, `abundance.py`, `matrix.py` | **FAIL** (all import `shock`) |

This precisely explains what works and what doesn't: `/annotation/*` uses `cassandra_handle()` ->
`mgrast_cassandra` (imports fine, works), while `/profile` and `/matrix` go through unimportable modules.
Hence 247 `/profile` + 17 `/matrix` stuck children and nothing else.

On the ~1-in-15 occasions the fork does *not* deadlock, the child dies on this ImportError at
`profile.pm:323` — **before `$mgcass` exists**, so `Profile.error_exit()` can never run and no error is
written. `create_profile` at `profile.pm:303` has no `eval{}` around it.

## Why the status endpoint hangs rather than failing

`profile.pm:161-171`: `status` is hard-coded `processing` unless the Shock node has a file.
The child never uploads data *or* an error, so the node stays file-less indefinitely. The parent already
returned `submitted`. Nothing times out.

## Explicitly ruled out

- **Cassandra** — healthy. `COUNT(*)` for job 7279 -> 76,791 and job 1512 -> 72,036; `/annotation` returns
  real rows; the stuck children hold **zero** sockets to 9042.
- **The NULL `job_info` columns** — irrelevant here. `profile.py` only calls `get_job_records()` /
  `get_lca_records()`, which select on PK `(version, job)`. `is_loaded()`, `get_info_count()`,
  `has_job()` and `get_job_info()` are never reached on this path.
- **Shock** — works; temp nodes are created correctly on every submit.
- **The one `status: done` response** was a *cached static* Shock profile node via
  `check_static_profile()`, not a successful compute. Treat every `done` as a pre-2026-05-19 artifact.

## All affected sites — `cassandra_test()` in the parent, then `fork()`

| file | parent-side Python | `fork()` |
|---|---|---|
| `resources/profile.pm` | 264 | **298** |
| `resources/matrix.pm` | 239 | **253** |
| `resources/compute.pm` | 240 | **287** |
| `resources/job.pm` | 464 | **485** |
| `resources/job.pm` | 1107 | **1127** |

Image `mgrast/api-server:latest` = `sha256:447860e9`, **built 2023-04-27**; containers started
2026-05-19. A long-standing regression, not a new break.

## Fix

1. **Stop forking an initialized embedded CPython.** Best: `fork()` + **`exec`** a standalone worker so
   the child gets a clean interpreter. Or hand the work to AWE (`awe-server@1`, `awe2-server@1` are both
   up). Or, if the fork must stay, **fork before any Python is touched** — move `cassandra_test()` into
   the child at all five sites.
2. **Port pylib to Python 3** — otherwise the non-deadlocked path still dies. Minimum: `shock.py`
   (`cStringIO` -> `io.BytesIO`/`StringIO`, `urllib.quote` -> `urllib.parse.quote`), then audit
   `profile.py`, `abundance.py`, `matrix.py`. Requires an image rebuild and updating
   `/service_images/api-server/shock` in etcd.
3. **Cheap robustness:** `eval{}` around `create_profile` (`profile.pm:303`) and write failures into the
   Shock node so the status endpoint reports an error instead of hanging; add a watchdog for temp nodes
   whose compute is dead.
4. **Operational:** the 1,040 leaked children hold memory and fds and will keep accumulating until the
   `api-server-api` containers are restarted. Nothing was restarted during the investigation.

## Separate issue: `/metagenome?limit=N` -> `total_count: 0`

Different root cause, unrelated to the above. `metagenome.pm:324-443` queries **Solr** at
`$Conf::job_solr = http://bio-worker2.mcs.anl.gov:8983/solr`, collection `metagenome_1`. But:

```
solr-m5nr@1.service               launched  launched   140.221.76.69
solr-metagenome@1.service         launched  inactive   -
solr-metagenome-backup@1.service  launched  inactive   -
```

**`solr-metagenome@1` is not scheduled to any machine.** `140.221.76.69:8983` answers 200 (that is the
m5nr Solr); `140.221.76.68:8983` refuses connections. The index `/metagenome` depends on does not
currently exist.

Elasticsearch is a *different*, healthy backend: cluster `mgrast` **green**, 7 data nodes, alias
`metagenome_index -> metagenome_index_20180705`, 1,437,262 docs / 82,776 public. Accordingly
`/search?limit=1` works and reports `total_count: 82776` while `/metagenome?limit=1` reports 0.

Probable reason it cannot be scheduled: `solr-metagenome` conflicts with `api-server` in `[X-Fleet]`, and
`api-server@4.api` occupies .68. Fixing it means freeing a conflict-compatible host, and the collection
may need reindexing after years of downtime. (The `[X-Fleet]` conflict was inferred from `CLAUDE.md`, not
read from the unit file.)

## Not established

- The precise lock the child blocks on (CPython GIL vs a driver-internal lock) — kernel-level evidence
  only; no `gdb`/`py-spy` in the image.
- Which call leaves driver threads alive at fork time in the *real* request. `CassTest.test()` does call
  `cluster.shutdown()`, yet the live serving CGI had 4 OS threads. Not isolated. Does not change the
  diagnosis or the fix.
- Whether `/profile` has ever worked in this image. Probably not since 2026-05-19, but not proven.
- Whether Shock's temp-node expiration reaper is working — orphaned 1-day temp nodes may be piling up.
