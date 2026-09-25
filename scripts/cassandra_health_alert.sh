#!/bin/bash
# Cassandra health alerter. Runs from an OPERATOR WORKSTATION via cron, NOT on a
# cluster host, for two reasons:
#   1. SMTP is unreachable from the bio-worker hosts (25 and 587 both closed).
#   2. A monitor inside the system it watches cannot report that the system failed.
#
# Reads the signal published by cassandra-simple-health@N.service out of etcd.
#
# AUTH: uses a dedicated passphrase-less key restricted in authorized_keys to a
# single forced command (a read-only etcd HTTP GET). It cannot get a shell, a pty,
# or run anything else - verified on install. Do not replace it with an
# unrestricted key; cron cannot use the passphrase-protected operator keys and
# stripping a passphrase off one of those would hand full cluster access to
# anything that reads the file.
#
# Emails on state change (ok->bad, bad->ok) plus a reminder every REMIND seconds
# while still bad. A first run against a healthy cluster is deliberately silent.
#
# Recipient defaults to the local user, which this workstation's Postfix relays as
# <user>@$mydomain. Override with CASSANDRA_ALERT_TO=someone@example.org
set -u

NODES="${CASSANDRA_ALERT_NODES:-140.221.76.73 140.221.76.70 140.221.76.12}"
KEY="${CASSANDRA_ALERT_KEY:-$HOME/.ssh/cassandra_health_cron}"
TO="${CASSANDRA_ALERT_TO:-$(id -un)}"
STATE_FILE="${CASSANDRA_ALERT_STATE:-$HOME/.cassandra_health_state}"
REMIND="${CASSANDRA_ALERT_REMIND:-21600}"
MAX_AGE="${CASSANDRA_ALERT_MAX_AGE:-180}"

now=$(date -u +%s)
json=""; via=""

# The key's forced command returns the whole subtree with values in one GET, so no
# remote script needs deploying and nothing but a read can happen.
for n in $NODES; do
  j=$(timeout 60 ssh -n -o BatchMode=yes -o IdentitiesOnly=yes -i "$KEY" \
        -o ConnectTimeout=10 core@"$n" true 2>/dev/null)
  case "$j" in '{"action"'*) json="$j"; via="$n"; break ;; esac
done

problems=""; oknum=0; total=0
if [ -z "$json" ]; then
  state=BAD
  problems="\n  UNREACHABLE: no etcd read succeeded from any of: $NODES"
else
  raw=$(printf '%s' "$json" | python3 -c '
import json,sys
inst={}; health={}
def walk(n):
    if n.get("dir"):
        for c in (n.get("nodes") or []): walk(c)
    else:
        k=n["key"]; leaf=k.rsplit("/",1)[1]
        if "/instances/" in k: inst[leaf]=n.get("value","")
        elif "/health/" in k: health[leaf]=n.get("value","")
try:
    walk(json.load(sys.stdin)["node"])
except Exception as e:
    sys.exit(1)
for i in sorted(inst): print(i, health.get(i,"ABSENT"))
' 2>/dev/null)

  if [ -z "$raw" ]; then
    state=BAD
    problems="\n  PARSE-FAILED: etcd returned data but no instances could be read (via $via)"
  else
    while read -r inst status ip ts rest; do
      [ -z "${inst:-}" ] && continue
      total=$((total+1))
      case "${status:-}" in
        ABSENT) problems="$problems\n  $inst  MISSING (health unit dead or unscheduled)" ;;
        ok)
          age=$(( now - ${ts:-0} ))
          if [ "$age" -gt "$MAX_AGE" ]; then problems="$problems\n  $inst  STALE (${age}s old, ip $ip)"
          else oknum=$((oknum+1)); fi ;;
        fail:*) problems="$problems\n  $inst  $status (ip $ip)" ;;
        *)      problems="$problems\n  $inst  UNPARSED: $status $ip $ts" ;;
      esac
    done <<< "$raw"
    [ "$total" -eq 0 ] && problems="$problems\n  no cassandra-simple instances registered in etcd"
    state=OK; [ -n "$problems" ] && state=BAD
  fi
fi

prev_state=UNKNOWN; prev_alert=0
[ -r "$STATE_FILE" ] && read -r prev_state prev_alert < "$STATE_FILE" 2>/dev/null || true
prev_alert=${prev_alert:-0}

send=no
[ "$state" != "$prev_state" ] && send=yes
# never mail "recovered" merely because there was no prior state (first run, or the
# state file was lost) - a healthy cluster must stay silent
[ "$prev_state" = UNKNOWN ] && [ "$state" = OK ] && send=no
# re-remind while a fault persists so it is not forgotten after a single mail
[ "$state" = BAD ] && [ $(( now - prev_alert )) -ge "$REMIND" ] && send=yes

if [ "$send" = yes ]; then
  if [ "$state" = BAD ]; then
    subj="[cassandra] PROBLEM: $oknum/$total nodes ok"
    body="Cassandra health check FAILED at $(date -u +%Y-%m-%dT%H:%M:%SZ) (read via ${via:-none})\n\nProblems:$problems\n\nHealthy: $oknum of $total instances.\n\nInvestigate on a cluster host:\n  scripts/cassandra_health.sh\n  docker exec cassandra-simple nodetool status\n  journalctl -u cassandra-simple-health@N\n"
  else
    subj="[cassandra] RECOVERED: all $total nodes ok"
    body="Cassandra health recovered at $(date -u +%Y-%m-%dT%H:%M:%SZ) (read via $via)\n\nAll $total instances are actively serving.\n"
  fi
  if printf "%b" "$body" | mail -s "$subj" "$TO" 2>/dev/null; then
    echo "$state $now" > "$STATE_FILE"
  else
    echo "$(date -u +%FT%TZ) ALERT SEND FAILED to $TO" >&2
    echo "$state $prev_alert" > "$STATE_FILE"
  fi
else
  echo "$state $prev_alert" > "$STATE_FILE"
fi

if [ "$state" = OK ]; then
  echo "$(date -u +%FT%TZ) OK ($oknum/$total via ${via:-?})"
else
  printf "%s BAD (%s/%s via %s)%b\n" "$(date -u +%FT%TZ)" "$oknum" "$total" "${via:-none}" "$problems"
fi
[ "$state" = OK ] && exit 0 || exit 1
