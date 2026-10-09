# mgrast-config: where it survives, and which copy to trust

Surveyed 2026-10-08 across all reachable bio-workers. No secrets are reproduced here — this repo is
public and `mgrast-config` contains `ssh_key/` and `auth/`.

## Why this matters

`cloud-config/update_cloud_config_pxe.sh` builds the real PXE config from `~/git/MG-RAST-infrastructure/`
and **`~/git/mgrast-config/`**. The latter is not present on the operator workstation, which is the
standing blocker for making anything in `ssh_authorized_keys` survive a PXE reprovision — including the
`cassandra-health` monitoring key (see `scripts/README-cassandra-health.md`).

## The remote is dead

```
origin  git@gitlab.cels.anl.gov:MG-RAST/mgrast-config.git
```
`gitlab.cels.anl.gov` resolves (140.221.28.43) but **tcp/22 and tcp/443 are both unreachable**. It cannot
be cloned from origin. Every surviving copy is a clone on a cluster host.

## It is NOT one checkout — there are ~130, at ~30 different commits

Every service instance clones `mgrast-config` at start, so each host carries one per unit, frozen at
whenever that unit last started. Observed HEADs span **2016-10-12 to 2022-07-28**.

**Newest: `a57cddc` (2022-07-28, "Merge branch 'wilke/edit-access'")**, found on .69, .70, .72, .73, .74,
.76, .77, .67 and .13. It is a **complete** clone: 1,468 commits, **not shallow**, carrying
`origin/master`, `origin/wilke/edit-access` and `origin/wilke/neon`.

**Use one of these two — verified `git diff-index` clean:**

```
bio-worker17 (140.221.76.13):/media/ephemeral/confd/mgrast-config
bio-worker10 (140.221.76.76):/media/ephemeral/confd/mgrast-config
```

### Traps found in the survey

- **Same commit does not mean same tree.** At `a57cddc`, most hosts share worktree manifest
  `0d37dd7318b0`, but the `cassandra-simple` checkouts show `b09a51b7feb7` and some `api-server` ones
  `da983db130cf` — service start-up rewrites files in place. `.13:cassandra-simple/mgrast-config` reports
  `diff-index` **MODIFIED**. Always check cleanliness before trusting a copy.
- **Some clones are empty or have no `.git` at all** (1-3 MB, nothing in them): `.67:cassandra-simple`,
  `.11:confd`, `.12:confd`, `.12:elasticsearch`, `.72:api-server-3.api`, `.77:seqcenter`. Failed clones
  that nothing ever noticed, because unit start does not verify the clone.
- **The copy inside bw16's `cassandra-simple-aux` is NOT the newest** — it is `25efa44` (2021-02-18) with
  an uncommitted `services/cassandra/cassandra.yaml` modification. It is 17 months behind `a57cddc`. It
  was initially mistaken for the last surviving copy; it is not.
- **Do not run `git status`/`fsck`/`log` against a copy you intend to preserve byte-for-byte** — git
  rewrites `.git/index`'s stat cache, so the copy silently diverges from its source.

## Recovering it

Clone with `--mirror` from a clean source so every ref and all 1,468 commits come across, not just
`master`:

```bash
rsync -a --rsync-path="sudo rsync" \
  core@140.221.76.13:/media/ephemeral/confd/mgrast-config/ ./mgrast-config/
# or, to get a bare mirror of all refs:
git clone --mirror /path/to/that/copy mgrast-config.git
```

Then verify before trusting it:

```bash
git -C mgrast-config rev-list --count HEAD    # expect 1468
git -C mgrast-config branch -a                # expect master + wilke/edit-access + wilke/neon
test -f mgrast-config/.git/shallow && echo SHALLOW || echo "full history"
```

**It must not be pushed to this repository or any other public remote** — it holds `ssh_key/` and
`auth/`. A private remote, or the private `config` repo, are the options; that is an operator decision,
not something to default into.

## DONE 2026-10-08: rehomed to the workstation

Pulled from the verified-clean source to the path the generator actually reads:

```
bio-worker17:/media/ephemeral/confd/mgrast-config/  ->  ~/git/mgrast-config/
```

396 files / 7,810,672 bytes. Verified at content level, not by `git status`:

| check | result |
|---|---|
| commits | 1468 |
| HEAD | `a57cddc` 2022-07-28 "Merge branch 'wilke/edit-access' into 'master'" |
| shallow | no — full history |
| branches | `master`, `origin/master`, `origin/wilke/edit-access`, `origin/wilke/neon` |
| `git fsck` | clean |
| `git write-tree` vs `HEAD^{tree}` | **both `9bc92e109985681c425b45def56ee68df1c1476e`** |

Note the trap: immediately after rsync, `git diff-index --quiet HEAD` reported **MODIFIED**. That is a
stale stat cache — rsync preserves mtime but inodes and ctimes change. `git update-index --refresh`
cleared it, and the tree-hash comparison above is the real proof. Use `write-tree` vs `HEAD^{tree}`, not
`git status`, to verify a copied checkout.

A bare mirror also exists at `~/git/mgrast-config.git` (2.7 MB, all 5 refs, 1469 commits reachable,
`fsck` clean), because the upstream remote is dead and a single working copy is not a backup.

## The monitoring-key durability gap: confirmed open, and NOT a one-line fix

`cloud-config/keys.yaml` holds **7 keys**, and the `cassandra-health` key is **absent** — so the gap in
`scripts/README-cassandra-health.md` is real: a PXE reprovision drops the monitoring key.

How the key list reaches a node (`update_cloud_config_pxe.sh`):

```sh
PUBLIC_KEYS=$(cat ${CONFIG}cloud-config/keys.yaml | sed ':a;N;$!ba;s/\n/\\n/g')
${SED_CMD} -e "s;%ssh_authorized_keys%;${PUBLIC_KEYS};g" ... ${TEMPLATE} > cloud-config-pxe.yaml
```
`keys.yaml` is slurped verbatim into the template's top-level `ssh_authorized_keys:` block.

**Two reasons not to just append the key there:**

1. **It would be a security downgrade.** All 7 existing entries are plain, unrestricted `ssh-rsa` keys
   (operator workstations plus `root@warehouse13`). The `cassandra-health` key is deliberately
   **passphraseless** and is restricted on the live hosts to a single forced command
   (`command="…",no-pty,restrict` — a read-only etcd GET). Dropping it into this list unrestricted would
   hand a passphraseless key full shell access on every node.
2. **Option preservation through this path is unverified.** `coreos-cloudinit` hands
   `ssh_authorized_keys` entries to `update-ssh-keys`. Whether `command="…"` prefixes survive that path
   intact has **not** been tested here, and it must not be assumed. The substitution itself looks safe —
   `sed` uses `;` as its delimiter and the forced command contains no `;`, `&` or backslash — but that is
   only the generator, not `update-ssh-keys`.

**Preferred fix instead:** have the template write a dedicated
`/home/core/.ssh/authorized_keys.d/cassandra-health` via `write_files`, which reproduces the restricted
line byte-for-byte and keeps it out of the shared human-key list. The key itself is a *public* key, but it
should still live in `mgrast-config`, not in this public repository. **Not implemented — needs an operator
decision**, since it changes how production nodes grant SSH.
