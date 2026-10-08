#!/bin/bash
# Idempotently allow SSH from mgrast-01 (140.221.31.93) on one bio-worker, live + persisted.
#
# Run per host, e.g.:
#   for ip in 66 68 69 70 71 72 73 74 76 77 81 67 11 12 13; do
#     ssh core@140.221.76.$ip 'bash -s' < add-mgrast01-allowlist.sh | sed "s/^/140.221.76.$ip  /"
#   done
#
# Safe to re-run. Two traps it guards against:
#  - `iptables -A` would land the ACCEPT *after* the catch-all DROP and be inert, so we use -I INPUT 1
#    and then assert the resulting line number is lower than the DROP's.
#  - /var/lib/iptables/rules-save is hand-maintained and filter-only; regenerating it with a bare
#    `iptables-save` would capture Docker's chains, so we insert one line textually instead.
SRC=140.221.31.93
RS=/var/lib/iptables/rules-save
LINE='-A INPUT -p tcp -s 140.221.31.93 --dport 22 -j ACCEPT -m comment --comment "mgrast-01"'

# 1. live rule
if sudo iptables -C INPUT -p tcp -s $SRC --dport 22 -m comment --comment 'mgrast-01' -j ACCEPT 2>/dev/null; then
  live=already-present
else
  sudo iptables -I INPUT 1 -p tcp -s $SRC --dport 22 -m comment --comment 'mgrast-01' -j ACCEPT \
    && live=ADDED || live=FAILED
fi

# 2. persisted rule, before the DROP line
if sudo grep -q "$SRC" "$RS" 2>/dev/null; then
  pers=already-present
else
  sudo cp -n "$RS" "${RS}.bak-mgrast01" 2>/dev/null
  sudo sed -i "/--dport 22 -j DROP/i $LINE" "$RS" && pers=ADDED || pers=FAILED
fi

# 3. would the persisted file actually load?
sudo iptables-restore --test "$RS" >/dev/null 2>&1 && test=ok || test=RESTORE-TEST-FAILED

# 4. ordering sanity
pos_allow=$(sudo iptables -L INPUT -n --line-numbers | awk '/140.221.31.93/{print $1; exit}')
pos_drop=$(sudo iptables -L INPUT -n --line-numbers | awk '/DROP.*dpt:22/{print $1; exit}')
if [ -n "$pos_allow" ] && [ -n "$pos_drop" ] && [ "$pos_allow" -lt "$pos_drop" ]; then
  order=ok
else
  order=BAD-ORDER
fi

printf '%-26s live=%-14s persisted=%-14s restore-test=%-22s order=%s (allow@%s < drop@%s)\n' \
  "$(hostname -s)" "$live" "$pers" "$test" "$order" "${pos_allow:-?}" "${pos_drop:-?}"
