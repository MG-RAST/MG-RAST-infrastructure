# PLAN: fix the API fork deadlock + Python-2-on-3.9, rebuild and redeploy

Planned 2026-10-12 (read-only investigation; nothing built, changed or restarted). Companion to
`api-profile-fork-deadlock.md`, which has the diagnosis.

## Four findings that rewrite the brief

**1. Shock is NOT the distribution path — and there is no blocker.** `api-server@N.api.service` ignores
etcd/skycore entirely; the skycore line is commented out. The live line is
`ExecStartPre=.../pull_docker_image.sh %i`, which is `docker pull mgrast/api-server:${TAG}` from **Docker
Hub**, with `TAG` derived from `%i` (`api` -> `latest`, `api-dev` -> `dev`). Docker Hub is reachable from
cluster hosts. Separately: Shock works fine over **HTTP** (404 MB node pulled, 200, 3.5 s); only **HTTPS**
is dead, consistent with the known `shock-nginx` certificate/reload gap.

**2. Bug 2 has one cause and one commit.** `MG-RAST/MG-RAST` commit **`56a3102a` "Set python version"
(2023-04-27)** flipped the Dockerfile from `python-dev`/`pip` to `python3-dev`/`pip3`. That is the entire
change. `src/MGRAST/pylib/` has not been touched since 2021. One Dockerfile commit moved the embedded
interpreter from 2.7 to 3.9 without porting the library.

**3. The deadlock is an `Inline::Python` 0.57 GIL bug, so "fork before Python" is fragile.** Measured in
the running container: Inline::Python 0.57's C sources contain **`Py_Initialize()` and nothing else** — no
`PyOS_AfterFork_Child`, no `pthread_atfork`, no `PyGILState_*`. Perl takes the GIL at init, never releases
it, and never tells CPython a fork happened. Decisively: **after `CassTest.test()` (which calls
`cluster.shutdown()`), `/proc/self/status` shows `Threads: 1`** — the driver threads are already gone, yet
the process is already poisoned. So the damage is in CPython's GIL/runtime state, not an inherited
live-thread lock. The child's first Python call does `take_gil()` and waits forever for a `drop_gil` from
a thread that no longer exists.

Consequence: candidate (c) "fork before touching Python" is only correct while nothing in the pre-fork
path ever spins a Python thread again, and the regression failure mode is a **142-day silent hang**.
Candidate (a) **fork + exec** discards the whole address space and is immune by construction.

**4. There is a live, fully-routed dev channel with zero production traffic.** `api-server@1.api-dev` on
**140.221.76.71**, published at `http://api-dev.metagenomics.anl.gov/` (verified 200), its own nginx
upstream pool, and **0 leaked children** (vs 247-268 on each prod host). It currently runs a *different*
image — `mgrast/api-server:dev`, built 2021-03-23, **Python 2.7.16** — so it has Bug 1 but not Bug 2,
making it the ideal place to prove the fork fix in isolation.

## Source of truth

| | |
|---|---|
| repo | `git@github.com:MG-RAST/MG-RAST.git`, branch **`master`**, HEAD `56a3102a` |
| Dockerfile | **repo root** (not `dockerfiles/api/Dockerfile`) |
| image name | **`mgrast/api-server`** (not `mgrast/api`) |
| cloned anywhere? | **No** — no MG-RAST checkout on the workstation or in editable form in the container |

**Deployed image == `master` exactly.** `92ae9e6d..master` is 1 commit ahead, 0 behind, and that commit
touches only the Dockerfile, which is already baked in. Building `master` reproduces production.

**`mgrast.yaml` is wrong and `dockbuild` would fail on it today**: wrong image name, wrong Dockerfile path
(`dockerfiles/*` is also in `.dockerignore`), no branch key. Fix as part of this work.

## Bug 2: the complete audit — 6 lines in one file

All 8 pylib files are **syntactically valid Python 3** (`py_compile` passes on every one): no `print`
statements, no `except X, e`, no `iteritems`/`has_key`/`basestring`/`unicode`/`xrange`, no implicit
relative imports. **`shock.py` is the only file with py2-only constructs**, and fixing it fixes all four
import failures (`shock`, `abundance`, `profile`, `matrix`).

| line | construct | severity | fix |
|---|---|---|---|
| `shock.py:13` | `import cStringIO` | **BLOCKER** | `import io` |
| `shock.py:269` | `cStringIO.StringIO(d)` | **BLOCKER** | `io.StringIO(d)` |
| `shock.py:16` | `import urllib` | needed for below | `import urllib.parse` |
| `shock.py:55` | `urllib.quote` | LATENT — breaks `add_acl` (making profiles public) | `urllib.parse.quote` |
| `shock.py:95`, `:170` | `urllib.urlencode` | LATENT — breaks `query_node`, `index_node` | `urllib.parse.urlencode` |
| `shock.py:266` | `open(d)` text mode | BEHAVIOURAL — corrupts binary/gzip uploads | `open(d, 'rb')` + `io.BytesIO` |

**Rejected alternative:** installing Python 2.7 and rebuilding Inline::Python against it. It works
(bullseye still ships `python2.7-dev`) but reverts the only thing `56a3102a` achieved, requires pinning
every dependency to 2020-era releases with no security support, is a larger diff than the fix, and is a
dead end at the next base-image bump. **The real port is 6 lines.**

## Recommended path

### Phase 1 — hotfix (small, reviewable, ships both bugs)

**Make `cassandra_test()` out-of-process** — one function in `resources/resource.pm` (1951-1961), zero
changes at the five call sites. Replace the in-process `py_eval` + `Inline::Python::Object` with
`system('/usr/bin/python3', $Conf::pylib_dir.'/cassandra_test.py', $db, @$hosts)` plus a ~15-line
`pylib/cassandra_test.py` wrapper exiting 0/1.

Why this beats (c): it **removes the poisoning source** instead of relying on statement ordering; it
**preserves** the pre-flight 500 ("unable to connect to metagenomics analysis database") that (c) would
turn into a `202 submitted` plus a Shock node that never completes; the parent's CPython stays
single-threaded and never loads the driver; and `cassandra_handle()` inherits the fix for free.

Same commit:
- the 6 `shock.py` edits above;
- **stop blinding the children.** `profile.pm:301-302`, `matrix.pm:256-257`, `compute.pm:290-291`,
  `job.pm:488-489` all `close STDERR; close STDOUT;`. Redirect into the bind-mounted tmp dir instead
  (`start_container.sh` maps `-v ${SERVICE_DIR}/tmp/:/MG-RAST/site/CGI/Tmp/:rw`, so it lands on the host
  and survives restarts). **This is the highest-value diagnostic change in the plan** — a `die` in any
  child is currently completely invisible;
- `eval{}` around the child body at all five sites, writing failures into the Shock node, and
  `POSIX::_exit(0)` rather than `exit 0` so the parent's END/DESTROY don't run in the child;
- `$SIG{CHLD} = 'IGNORE'` so children are reaped;
- status reporting (`profile.pm:161-171`): report `error` when the node's file is named `error`, and add a
  staleness guard so a dead compute reports `failed` instead of polling forever.

### Phase 2 — the real fix, separate PR
`fork()` + `exec` a standalone worker (`src/MGRAST/bin/mgrast_async_worker.pl`; the Dockerfile already
copies `src/MGRAST/bin/*`). The honest cost: the two `job.pm` sites have their logic written **inline in
the fork block**, so they need extracting into named subs first — a pure refactor, but the bulk of the
work, and not something to ship under incident pressure alongside a Python port.

Useful: three **existing synchronous paths** (`job.pm:1125-1128` `$sync`, `compute.pm:248` non-async,
`profile.pm:291-295` `$debug`) are a fork-free in-container test harness for the worker logic. Convert in
order of blast radius: `profile.pm` -> `compute.pm` -> `matrix.pm` -> `job.pm:485` -> `job.pm:1127`.

### Phase 3 — long term
AWE, or retire `Inline::Python` for a small Python HTTP service in front of Cassandra. The AWE client
already exists (`resource.pm:1577-1886`, 22 `.awf` templates) but **both `awe-worker@*.ebi_submit` units
are inactive/dead**, so it is a multi-week project.

## Build — one non-negotiable change

```diff
- FROM httpd:2.4
+ FROM httpd@sha256:28074b6f3722be675b200c1c87c288066e90972e96ee51d87f83d763dc4e09a1   # 2.4.57, bullseye
```
`httpd:2.4` **today resolves to 2.4.69-trixie (Debian 13)**, published 2026-10-06. Rebuilding `master`
unchanged would produce a Debian 13 image with Python 3.11/3.13 — a different platform entirely, which
invalidates the whole audit above. Production is httpd 2.4.57 / bullseye / Python 3.9.2.

Also pin the currently-unpinned installs so the rebuild is a one-variable change:
`cassandra-driver==3.26.0  pika==1.3.1  requests==2.29.0  requests_toolbelt==0.10.1`, and
`Inline::Python` 0.57.

**Build host: the workstation cannot do it** (no running dockerd, no subuid/subgid, no fuse-overlayfs,
`$HOME` on NFS, 1 CPU / 3 GB RAM / 23 GB free; the image is 1.3 GB and compiles R + BiocManager).
Recommended **`core@140.221.76.12`** (load 0.70, 1.3 T free) or `.13` (4.2 T free). **Not** an api host
(`[X-Fleet] Conflicts=api-server@*`) and not `.70` (nginx). Cluster Docker is **17.09.1-ce, no buildx** —
the classic builder handles this Dockerfile, but **verify `docker pull httpd:2.4.57` works on 17.09 as
step 0**; that is the one real unknown.

Acceptance test for Bug 2, run against the built image before it leaves the host — all 7 must print OK:
```bash
for m in cass_connection mgrast_cassandra m5nr shock abundance profile matrix; do
  python3 -c "import sys;sys.path.insert(1,'/MG-RAST/site/lib/pylib');import $m" && echo "OK $m" || echo "FAIL $m"
done
```

## Deploy and rollback

Docker Hub, staged: push `:dev` -> validate on the dev channel -> push `:latest` -> roll the four prod
instances one at a time. Keep the immutable date-stamped tag forever as the rollback anchor.

| unit | host |
|---|---|
| `api-server@1.api` | .77 |
| `@2.api` | .11 |
| `@3.api` | .69 |
| `@4.api` | .68 |
| `@1.api-dev` | .71 |

**Rollback is already guaranteed**: the current image (`sha256:f29853f5…`) is cached on all four prod
hosts *and* carries the immutable Hub tag `20230427-01` with the identical digest. **Gotcha:**
`pull_docker_image.sh` pulls `:latest` on every start, so a local re-tag is overwritten — a durable
rollback requires **pushing the old image back to `:latest`** (lossless, digest unchanged).

**Step 0, before any code is written:** reproduce Bug 1 on the dev instance (py2 image, 0 leaked
children — the cleanest possible control). If a hung `api.cgi` appears there, the GIL analysis is
confirmed; if it does not, the strategy needs revisiting. **This experiment was deliberately not run**
to avoid creating a hung process in production.

Start prod rollout with **`@4` (.68)** — it holds the worst leak (10.6 GB of 15 GB total) so it is the
largest single win, and nginx drops it from the pool while it restarts. End with **`@1` (.77)**, which
also hosts `mongodb-replica@3.awe`.

## The 1,040 leaked children

| host | children | RSS | oldest |
|---|---|---|---|
| .77 | 268 | 0.8 GB | 141.4 d |
| .11 | 257 | 1.9 GB | 139.6 d |
| .69 | 247 | 1.8 GB | 142.5 d |
| .68 | 268 | **10.6 GB** | 142.5 d |
| **total** | **1,040** | **~15 GB** | |

**The deploy clears them as a side effect** — `start_container.sh` uses `docker run --rm` and the unit's
`ExecStop`/`ExecStartPre` tear the container down, killing everything in its PID namespace. No separate
step needed. For early relief on `.68`, kill only children with `etimes > 3600` so a live request is never
hit. They accrue at ~7-8 per host per day, so killing is symptom relief only.

## Two security items found incidentally

- **`pylib/cass_connection.py:8-11` hardcodes RabbitMQ credentials in plaintext** in a public GitHub
  repo, pointing at `bio-worker20.mcs.anl.gov` — which **is not in `fleetctl list-machines`**. If it is
  dead, `mgrast_cassandra.py:42-45` opens a *blocking* pika connection inside a bare `try/except: pass`
  on every handle creation, so every Cassandra handle may be paying a connect timeout. Worth checking;
  possibly a latency bug hiding in plain sight. Credentials should be rotated regardless.
- `/home/wilke/.docker/config.json` stores the Docker Hub password as reversible base64 on an **NFS**
  home. Worth rotating to a scoped access token.

## Decisions needed from the operator

1. Branch off **`master`** (recommended) or `develop`? `develop` is 24 ahead / 6 behind with PR **#1453**
   open since 2021, and carries a real `mgrast_cassandra.py` corruption guard production lacks. Land
   #1453 separately rather than folding it into a hotfix.
2. Phase 1 only now, Phase 2 as a follow-up? (recommended)
3. Accept the out-of-process `cassandra_test` hotfix in place of candidate (c)?
4. Pin `FROM httpd@sha256:28074b6f…` — considered non-negotiable; confirm.
5. Pin the pip set?
6. Build host: `.12`, `.13`, or off-cluster?
7. **Identify `mgrast/api-server:20240429`** — pushed 2024-04-29, 526 MB, **newer than `:latest`** and
   never promoted. Nobody should rebuild without knowing what it is.
8. Preserve the 2021 py2 `:dev` image as `dev-2021` before overwriting `:dev`?
9. Rotate the Docker Hub credential?
10. Which metagenome id for the Step 0 / Step 1 async reproduction test?
11. Kill the 1,040 children now, or let the deploy do it? (recommended: let the deploy)
12. Delete the three stale `/service_images/api-server-api*` etcd keys (they point at a **2018** image)
    and the orphan `/services/api-server/api-pql`?
13. Soak windows between deploy steps, and the profile staleness threshold.

## Not established

- Whether fork+exec fixes it **in situ** — the GIL analysis is grounded in measured facts but the Perl
  fork experiment was deliberately not run in production. Step 0 settles it.
- Whether `Py_Initialize()` alone is fork-safe (the premise candidate (c) rests on). Strongly implied by
  the py2 `:dev` image working for years, not proven. Another reason to prefer (a).
- What `:20240429` is; whether Docker 17.09 can pull `httpd:2.4.57`; whether the stored Hub credential
  still authenticates; whether `pip3` with 2026 package versions still builds on py3.9/bullseye.
- Why `ls /MG-RAST/` returns `Operation not permitted` in the container even as root while `cat` works.
- Whether `matrix.pm`'s `$metadata`/`$hierarchy` are cleanly JSON-serializable for a Phase 2 spec file.
