#!/bin/bash
# Read the cassandra-simple active health signal out of etcd and report.
# Run on any cluster host. Exit 0 if everything is ok, 1 if anything is not.
#
# Companion to fleet-units/cassandra-simple-health@.service. Three states per node:
#   ok               -> probe passed (JMX + real CQL read)
#   fail:<reason>    -> probe ran, node is sick
#   MISSING          -> etcd key expired: the health unit itself is dead/unscheduled
#
# Also flags STALE keys: a key present but older than --max-age (the probe refreshes
# every 45s with a 150s TTL, so anything older than ~150s should not normally exist).

SERVICE=cassandra-simple
MAX_AGE=${MAX_AGE:-180}
NOW=$(date -u +%s)
rc=0

instances=$(etcdctl ls /services/${SERVICE}/instances 2>/dev/null | sed "s|.*/||" | sort -V)
[ -z "$instances" ] && { echo "ERROR: no ${SERVICE} instances registered in etcd"; exit 1; }

printf '%-28s %-10s %-22s %s\n' INSTANCE STATE DETAIL AGE
for i in $instances; do
  v=$(etcdctl get /services/${SERVICE}/health/${i} 2>/dev/null)
  if [ -z "$v" ]; then
    printf '%-28s %-10s %-22s %s\n' "$i" "MISSING" "health unit dead?" "-"
    rc=1
    continue
  fi
  status=$(echo "$v" | awk '{print $1}')
  ip=$(echo "$v"     | awk '{print $2}')
  ts=$(echo "$v"     | awk '{print $3}')
  age=$(( NOW - ${ts:-0} ))

  note="$ip"
  state=ok
  case "$status" in
    ok)    ;;
    fail:*) state="$status"; rc=1 ;;
    *)      state="ODD"; note="unparsed: $v"; rc=1 ;;
  esac
  if [ "$age" -gt "$MAX_AGE" ]; then
    state="STALE"; note="$ip (last ok-ish report)"; rc=1
  fi
  printf '%-28s %-10s %-22s %ss\n' "$i" "$state" "$note" "$age"
done

if [ $rc -eq 0 ]; then
  echo "ALL OK - every ${SERVICE} instance is actively serving"
else
  echo "PROBLEMS FOUND - see non-ok rows above"
fi
exit $rc
