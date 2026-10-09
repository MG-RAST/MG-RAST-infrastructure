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
