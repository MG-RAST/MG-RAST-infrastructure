# RUNBOOK — Cassandra internode TLS CA rotation

> **This is the redacted copy, for the public `MG-RAST-infrastructure` repo.**
> Key-handling specifics and the node/IP inventory are omitted. The unredacted version lives in the
> private `config` repo at `services/cassandra/RUNBOOK-cassandra-ca-2026-09-22.md`, next to the material
> it describes. Look here first; go to `config` for the operational specifics.

**Drafted** 2026-09-22 · **Binding deadline** 2026-10-10 21:02 UTC · **Target completion** 2026-10-02 (buffer)
Reviewed against Cassandra 3.11.4 and JDK 8u222 source + empirical JSSE handshake tests.


## 0. PROGRESS (live) — last updated 2026-09-22

**Phase 0 COMPLETE. Phase 1 staged on bw16 + bw12. No node restarted yet.**

| Step | State |
|---|---|
| get_lock.sh branch fix | **DONE** — committed `3238f79`, pushed to `MG-RAST/config` main |
| seed1 -> bw7 (<node-ip>) | **DONE** — verified consistent across 5 etcd members |
| bw19 zombie `@8` + discovery stopped | **DONE** — inactive/dead; discovery key expired; instance keys 15 -> 14; `<node>` gone from api conf |
| CSR <-> keystore key match, all 14 | **DONE** — 14/14 MATCH, all fingerprints distinct |
| Renewed CA generated | **DONE** — serial `E1AA47D85B44820E`, to 2036-09-19; gates: pubkey unchanged / Version 1 / DN identical / no extensions |
| 14 leaves re-signed | **DONE** — every leaf verifies against BOTH old and renewed CA; CN == node IP |
| New JKS truststore | **DONE** — `feedfeed` magic, type JKS, alias rootca to 2036 |
| Image digest check | **DONE** — all 14 on `8b4eae6a3533`; Docker Hub `:3.11` digest `sha256:7e322c5d...` MATCHES on-node, so the ExecStartPre pull is a no-op |
| Clock check | **DONE** — all 14 within ~1s of UTC. NB `timedatectl` says "System clock synchronized: no" while timesyncd is active and time is correct — misleading flag, not a real skew |
| Renewed CA + truststore -> config repo | **DONE** — committed `81f0f3e`, pushed |
| Stage bw16 (`@1`, .12) | **DONE** — backup `ssl.bak-2026-09-22` (11 files); keystore key match PASS; 4 files staged; live keystore mtime still 2021-04-09 |
| Stage bw12 (`@15`, .67) | **DONE** — backup `ssl.bak-2026-09-22` (11 files); keystore key match PASS; 4 files staged; live keystore mtime still 2016-10-12 |
| **bw16 canary restart** | **DONE 2026-09-22 — ALL GATES PASSED** |
| **bw12 restart (`@15`, .67)** | **DONE 2026-09-22 — ALL GATES PASSED** |
| **All 10 MANDATORY nodes rotated** | **DONE 2026-09-22 — deadline risk retired** |
| bw2 `@9`, bw17 `@10`, bw6 `@11` | **DONE 2026-09-22** |
| **ALL 14 NODES ROTATED** | **COMPLETE 2026-09-22** |

### bw12 result (`@15`, .67) — the mandatory node with the most history
Leaf was expiring **2026-10-10**; now **2036-09-19**. Drain 11 s, restart -> UN **135 s** (3.08 TiB,
3x bw16's data, yet only ~19 s slower — startup cost tracks sstable count, not bytes).
Gates: ring 14 UN; 1 distinct schema version; on-wire cert 2026->2036; live keystore rootca 2036 +
PrivateKeyEntry chain length 2; **0 SSL errors and 0 ERROR lines** (confirming bw16's single error really
was just the `s_client` probe); `lock key exists`/`Cannot acquire lock...`; seed1 still `<node>`.
Post-restart filesystem check: `btrfs device stats` corruption_errs **0**, generation_errs **0**,
Load 3.08 TiB intact — the formerly-quarantined node took a full `chown -R` restart cleanly.

### Rotation log — 2026-09-22, 11 of 14 nodes

| node | inst | drain | notes |
|---|---|---|---|
| bw16 | @1  | 33 s  | canary |
| bw12 | @15 | 11 s  | formerly-corrupt node; btrfs clean after |
| bw10 | @3  | 13 s  | |
| bw8  | @4  | 10 s  | |
| bw5  | @5  | 8 s   | |
| bw11 | @7  | 13 s  | |
| bw13 | @12 | 24 s  | |
| bw3  | @14 | 12 s  | |
| bw15 | @16 | 110 s | long drain, more memtable to flush |
| bw4  | @17 | 10 s  | |
| bw7  | @13 | 90 s  | the seed — did NOT rewrite seed1, fix confirmed again |

Every node passed identical gates: UN, ring 14 UN, 1 schema version, 0 SSL / 0 ERROR,
seed1 unchanged at `<node>`, on-wire cert `notAfter 2036-09-19`.
Restart-to-UN was ~2 min throughout regardless of load (1 TiB to 3.4 TiB).

**ALL 10 MANDATORY NODES DONE — nothing now expires on 2026-10-10.**

### Remaining (OPTIONAL, no deadline)
`@9` bw2 (.68), `@10` bw17 (.13), `@11` bw6 (.72) — leaves valid to 2027-08 / 2027-09 / 2027-04.
They still hold the ORIGINAL rootCa (expiring 2026-10-02) in keystore+truststore. Safe, because
Java's SunX509/SimpleValidator never validity-checks the trust anchor (§2), and their own leaves are
years out. They interoperate with the 11 rotated nodes in both directions (proven in production today).

**ALL 14 NODES ROTATED — 2026-09-22.** bw2 (drain 69 s), bw17 (drain 75 s), bw6 (see below) all passed
every gate. Cluster: 14 UN / 2 DN (`<node>`, `<node>`), 1 schema version, seed1 `<node>`, every keystore and
truststore now on the renewed CA to 2036-09-19.

### bw6 (`@11`, .72) — the one that did not go to plan, and what it uncovered
`nodetool drain` **hung for >12 minutes** (every other node: 8–110 s). Investigation showed the cause was
not the drain: **bw6's Cassandra server had logged nothing since 2026-07-07** — 2.5 months — while the
container read `Up 4 months`, the node showed **UN**, and gossip was active. The server was wedged and not
servicing the JMX drain request.

Because the drain had already taken the node to DN, and the chain was newline-joined (so it would have
fired `mv` + `restart` unsupervised whenever drain returned), the hung chain was killed first, then the
swap and restart were done deliberately. **The restart cleared the wedge**: bw6 resumed logging immediately
(compaction/large-partition warnings within minutes) and returned UN with the new cert.

**Operational lesson worth keeping: a node can sit UN with gossip active while its Cassandra server is
wedged and silent for months.** `nodetool status` alone would never have surfaced this. Add a staleness
check on each node's last log line, or on a per-node liveness metric, to the monitoring.

### Reference — per-node commands (for future rotations)
```
scp rootCa_new.crt generic-server-truststore.jks.new <ip>.crt_signed.new <ip>.chain.new.pem core@<ip>:/tmp/ca-stage/
ssh core@<ip> 'bash -s' -- <ip> <inst> < rotate.sh
```

### Canary result — bw16 (`@1`, .12), 2026-09-22

| Gate | Result |
|---|---|
| Ring | 14 UN / 2 DN — unchanged |
| Schema agreement | single version across all 14 |
| On-wire cert on :7002 | **2026-09-22 -> 2036-09-19** (was 2021 -> 2031) |
| Peers accept it | **YES** — the other 13 still hold the OLD CA and connect fine |
| Live keystore | rootca 2036 + PrivateKeyEntry, chain length 2, both 2036 |
| SSL errors from peers | **0** (the single logged one was my own `s_client` probe from bw7 — no client cert, `null cert chain`, expected under require_client_auth) |
| `get_lock.sh` in situ | `lock key exists` / `Cannot acquire lock...` — **fix confirmed**, no `got lock!` |
| seed1 after restart | still `<node-ip>` on 3 members — **not hijacked** |

**Timings** (bw16 = smallest node, 1013 GiB — treat as a LOWER bound for the 3 TiB nodes):
- `nodetool drain`: **33 s**
- restart -> UN: **~116 s**
- total per node: **~2.5 min**, well inside the 3 h `max_hint_window_in_ms`

**This is the decisive proof of the whole approach**: a node presenting a cert signed by the renewed CA is
accepted by 13 peers that still trust only the old CA certificate — because the CA public key is unchanged.
Mixed old/new is confirmed safe in production, so the remaining nodes can go one at a time in any order.

Staged material per node, in `/media/ephemeral/cassandra-simple/ssl/`:
`keystore.jks.new`, `generic-server-truststore.jks.new`, `rootCa_new.crt`, `<ip>.crt_signed.new`.
Live `keystore.jks` / `generic-server-truststore.jks` deliberately untouched.

Cluster at time of writing: **14 UN / 2 DN** (`<node>`, `<node>` — the long-standing foreign members).
Generated material was produced in a scratch directory and not retained. To regenerate it, re-run the
steps in §3 against `config/services/cassandra/rootCa.{crt,key}` — the renewed CA is already committed to
the `config` repo, and each node still holds its own `<ip>.csr`. Never commit `rootCa.key` anywhere new;
it lives only in the `config` repo.

### Swap commands for the restart (per node)
```
S=/media/ephemeral/cassandra-simple/ssl
sudo mv $S/keystore.jks.new                  $S/keystore.jks
sudo mv $S/generic-server-truststore.jks.new $S/generic-server-truststore.jks
```
Atomic `mv` on the same filesystem — never edit in place, a live node re-reads these per outbound connection.
Rollback: `sudo cp -a $S.bak-2026-09-22/. $S/` then restart.

## 1. What is expiring and when

| Item | Expires | Binding? |
|---|---|---|
| `rootCa.crt` (all 14 nodes, keystore **and** truststore) | **2026-10-02** 21:31 UTC | **No** — see §2 |
| node leaf certs, 10 of 14 nodes | **2026-10-10** 21:02 UTC | **YES** |
| node leaf certs, bw16 / bw17 / bw6 / bw2 | 2031 / 2027 / 2027 / 2027 | no |
| `cassandra_client_cert.*` | 2026-10-03 | no — `client_encryption_options.enabled: false` |

`server_encryption_options`: `internode_encryption: all`, `require_client_auth: true` → **mutual** internode TLS.
Losing this breaks gossip ring-wide.

## 2. The trust-anchor expiry does NOT matter (corrected)

`cassandra.yaml` leaves `algorithm:` commented out; Cassandra 3.11.4 `EncryptionOptions` defaults it to
`SunX509` → `sun.security.validator.SimpleValidator`, **not** PKIX.

`SimpleValidator.engineValidate` (jdk8u222-b10) walks `for (int i = chain.length - 2; i >= 0; i--)` —
index `length-1`, the trust anchor, is **never** validity-checked. PKIX likewise excludes the anchor (RFC 5280).
Verified empirically: a same-DN/same-key root expired in 2016, present in the truststore *and* in the presented
chain, still completes a full mutual-TLS handshake under both SunX509 and PKIX.

**Therefore the 2026-10-02 CA expiry is not a cliff. The real cliff is 2026-10-10 (leaf certs).**
Plan to 10-02 for buffer, but do not panic-restart on 10-02.

## 3. Core technique — same-key CA renewal (PROVEN)

Renew the CA **in place, same RSA key pair, same subject DN**, and re-sign each node cert from its **own existing
CSR** (present on every node). The node private keys are never touched.

    openssl x509 -in rootCa.crt -signkey rootCa.key -days 3650 -set_serial 0x<new> -out rootCa_new.crt
    openssl x509 -req -in <ip>.csr -CA rootCa_new.crt -CAkey rootCa.key -days 3650 -out <ip>.crt_signed.new

Because the CA public key is unchanged, `SimpleValidator.getTrustedCertificate` matches a presented root against a
truststore root on **subject DN + issuer + public key** and substitutes the truststore copy as the anchor. So
updated and not-yet-updated nodes trust each other **in both directions**. Verified by full mutual-TLS handshakes
across every old/new combination, and on a real copy of bw7's keystore.

**=> ONE rolling restart, 14 nodes, no ordering constraint.** (Textbook two-phase would be 28 restarts + a barrier.)

### Hazards that make this fragile — do not deviate
- Check how `rootCa.key` is protected before scripting around it; the `-passin` handling is described in
  the `config` copy of this runbook. Do not copy the CA key out of the `config` repo.
- The CA is **v1 with no extensions**. `-signkey` preserves that. **Never** rebuild it via `openssl req`/`openssl ca`:
  that re-orders the RDNs and **DN byte-equality is load-bearing** — trust fails outright ("No trusted certificate found").
  A v3 cert *without* basicConstraints is the one shape to never produce (PKIX rejects it; SunX509 tolerates it).
- `-signkey` **reuses serial `E0A1AC20FAEC5D32`**. JSSE does not care; pass `-set_serial` anyway.
- Verify after generating: `openssl x509 -in rootCa_new.crt -noout -text | grep -E 'Version|Subject:'`
  must show `Version: 1` and a byte-identical subject line.

## 4. BLOCKER — `get_lock.sh` has inverted branches (fix before anything else)

    etcdctl set --swap-with-value '0' .../lock1 '1'
    if [ $? -eq 0 ]; then   # swap SUCCEEDED (we got the lock) -> but body says "Cannot acquire lock", waits
    else                    # swap FAILED (someone holds it)   -> but body says "got lock!", SETS seed1=own IP

Verified on the cluster's etcd: `--swap-with-value` exits **0** on success, **4** on compare failure.
`lock1` is currently `1`, so **every restarting node overwrites `seed1` with its own IP** and then boots with
`CASSANDRA_SEEDS=<itself>`. This is why `seed1` = bw12 today: bw12 was simply the last node restarted (2026-05-20,
after the rest on 05-19) — not a design choice.

Consequence: **re-pointing `seed1` without fixing the script is futile** — the first restart undoes it.

**Fix in Phase 0**: swap the two branch bodies, commit to the `config` repo. The fleet unit `rm -rf`s and re-clones
`config` on every start, so the fix is live from the first restart onward. With `lock1` pinned at `1`, no node will
ever rewrite `seed1` again — which is the correct behaviour for an already-bootstrapped cluster.

## 5. Phases

### Phase 0 — prep (zero cluster impact)
0.1 ✅ done — per-node cert inventory (§7 table).
0.2 ✅ done — every node has `<ip>.csr`, `rootCa.key`, `completed.txt`.
    **TODO**: confirm each node's CSR public key still matches its keystore key (the 4 regenerated nodes especially):
    `keytool -exportcert -rfc -alias <ip> ... | openssl x509 -noout -pubkey | sha256sum`
    vs `openssl req -in <ip>.csr -noout -pubkey | sha256sum`
0.3 **Fix `get_lock.sh`** (§4) and commit to `config`.
0.4 Then `etcdctl set /services/cassandra-simple/seed1 <node-ip>` (bw7 — stable, UN). Now it sticks.
    Do **not** touch `lock1`.
0.5 `fleetctl stop cassandra-simple@8.service` (bw19 zombie: container up 4 months, JMX dead, not in the ring;
    `Restart=always` + the old script makes it a seed1-rewriting landmine).
0.6 Generate material off-cluster (`gen-material.sh`). Build the truststore with **`-storetype JKS`** — JDK 9+
    keytool silently creates PKCS12 otherwise and Cassandra opens `store_type=JKS`.
0.7 Pre-pull `mgrast/cassandra:3.11` on one host and compare `docker images --digests` against the running
    container's image ID. `ExecStartPre` does an **unconditional** `docker pull`; if the tag moved you would
    silently restart onto a different image/JRE.
0.8 Check `timedatectl` on all hosts. `notBefore` **is** enforced; new certs carry notBefore = generation time.
0.9 Commit renewed CA + new truststore to `config` **now** (inert for nodes with `completed.txt`; means any node
    that loses it regenerates against the renewed CA). Touch only `services/cassandra/`.

### Phase 1 — stage (no restart)
Per node: `cp -a /media/ephemeral/cassandra-simple/ssl{,.bak-2026-09-22}`, then write new material under
**different names** (`keystore.jks.new`, `generic-server-truststore.jks.new`).
⚠️ Staging is **not** fully inert: `SSLFactory.getSocket()` in 3.11.4 calls `createSSLContext()` per outbound
connection with **no cache**, so a live node re-reads these files from disk on every new outbound internode
connection. Only the inbound server socket is fixed at startup. **Never edit in place with keytool**; write to a
temp name on the same filesystem and `mv` atomically at swap time.

### Phase 2 — swap + rolling restart, ONE node at a time
Order: **bw16 (@1) first** as procedure canary (smallest load, 1013 GiB — note its leaf is valid to 2031, so it
proves the *restart*, not the deadline). Then the 10 mandatory nodes. **bw12 (@15) last.**
Per node:
1. `nodetool drain` — **mandatory**, not optional. `ExecStop=docker stop` gives SIGTERM + **10 s** then SIGKILL;
   a 3 TB node will not finish its flush in 10 s. After drain the SIGKILL is harmless (commitlog empty).
   Drain needs working JMX on 7199 and is irreversible without restart — only drain when committed.
2. atomic `mv` the new keystore + truststore into place.
3. `sudo systemctl restart cassandra-simple@N.service` on the host, **or** `fleetctl stop` + `fleetctl start`.
   Do **not** `docker stop` as a "stop" — `Restart=always` will bounce it back in 10 s.
   After `fleetctl stop`, confirm via `fleetctl list-units` the unit is still on the **same machine**.
4. Gate before proceeding:
   - `nodetool status` from **another** node shows UN
   - `nodetool describecluster` → schema agreement (not just UN)
   - on-wire: `openssl s_client -connect <ip>:7002 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -issuer -dates`
     (server chain is sent before the client-cert request, so it is readable even though the handshake then fails)
   - logs clean of `SSLHandshakeException|certificate_unknown`
5. Keep each node's downtime **under 3 h** (`max_hint_window_in_ms` = 3 h) or schedule `nodetool repair` after.
If a node does not return UN: **STOP**. Do not batch.

### Phase 3 — already folded into 0.9.

## 6. Risk posture

- **Quorum (RF=3, 16 ring members, 256 vnodes, SimpleSnitch).** `<node>`/`<node>` already DN ⇒ ~2.5% of ranges are
  already QUORUM-unavailable today. While restarting node X: ~0.18% of ranges fully unavailable (all CLs),
  ~4.6% additionally QUORUM-unavailable; ONE/LOCAL_ONE loses only the 0.18%. **Acceptable one-at-a-time.**
  **Do NOT `removenode` .75/.82 in this window** — multi-TB streaming for days, and any node restart mid-stream
  fails it. Do that after the rotation. *Open: confirm which CL the API actually uses.*
- **bw12 is in the mandatory 10.** If it is not restarted with a new leaf by **2026-10-10** it becomes a third DN
  member → 7.1% of ranges permanently QUORUM-unavailable. **Deferring bw12 entirely into §3.0d is only viable if
  §3.0d completes before 10-10.** This is a real scheduling conflict — decide explicitly.
- **Restart cost is low**: the entrypoint chown over ~3 TB took ~6 s on bw7's last start (metadata-only).
  Time the canary to confirm.
- **Rollback**: `/ssl.bak-2026-09-22` per node; `mv` back and restart. Old and new certs are mutually trusted,
  so a partial rollout is a safe resting state.

## 7. Node inventory (2026-09-22)

All nodes: rootCa expires Oct 2 2026; `csr` + `rootCa.key` + `completed.txt` present.

| inst | host | leaf expires | mandatory |
|---|---|---|---|
| @1 | bw16 | 2031-04-07 | no (canary) |
| @3 | bw10 | 2026-10-10 | **YES** |
| @4 | bw8 | 2026-10-10 | **YES** |
| @5 | bw5 | 2026-10-10 | **YES** |
| @7 | bw11 | 2026-10-10 | **YES** |
| @9 | bw2 | 2027-08-01 | no |
| @10 | bw17 | 2027-09-10 | no |
| @11 | bw6 | 2027-04-25 | no |
| @12 | bw13 | 2026-10-10 | **YES** |
| @13 | bw7 | 2026-10-10 | **YES** (seed target) |
| @14 | bw3 | 2026-10-10 | **YES** |
| @15 | bw12 | 2026-10-10 | **YES** — fragile, current seed, do last |
| @16 | bw15 | 2026-10-10 | **YES** |
| @17 | bw4 | 2026-10-10 | **YES** |

## 8. Unverified / open
- Behaviour on the exact 8u222 binary (tested on 8u502; decisive JDK source paths identical at the 8u222 tag).
  Closeable by running the review's `handshake.js` inside `mgrast/cassandra:3.11` on a workstation.
- Whether the image entrypoint uses `chown -R` or a `find`-based chown — time the canary.
- "seeds={self} on an already-bootstrapped node is benign" — from source reading, untested. The `get_lock.sh`
  fix makes it moot.
- Which consistency level the API uses (drives the quorum risk assessment).
