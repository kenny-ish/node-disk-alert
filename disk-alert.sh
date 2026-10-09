#!/usr/bin/env bash
# Disk usage + growth alerts for node operators.
set -euo pipefail

dir=$(cd "$(dirname "$0")" && pwd)
conf="$dir/disk-alert.conf"
state_dir="$dir/state"
TELEGRAM_TOKEN="" TELEGRAM_CHAT="" PATHS="/" THRESHOLD=85 MIN_DAYS=14
# shellcheck source=/dev/null
[[ -f $conf ]] && source "$conf"
mkdir -p "$state_dir"

notify() {
  echo "ALERT: $1"
  if [[ -n $TELEGRAM_TOKEN && -n $TELEGRAM_CHAT ]]; then
    curl -fsS -m 15 "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
      --data-urlencode "chat_id=$TELEGRAM_CHAT" --data-urlencode "text=$(hostname): $1" >/dev/null ||
      echo "telegram send failed" >&2
  fi
}

now=$(date +%s)
for path in $PATHS; do
  read -r size used avail < <(df -P -B1 "$path" | awk 'NR == 2 { print $2, $3, $4 }')
  pct=$((used * 100 / size))
  key=$(echo "$path" | tr '/' '_')
  state_file="$state_dir/$key"

  growth="n/a"
  days="n/a"
  if [[ -f $state_file ]]; then
    read -r prev_ts prev_used prev_alert <"$state_file"
    elapsed=$((now - prev_ts))
    if ((elapsed > 0)); then
      growth=$(awk -v d=$((used - prev_used)) -v t="$elapsed" 'BEGIN { printf "%+.1f", d / t * 86400 / 1e9 }')
      days=$(awk -v a="$avail" -v g="$growth" 'BEGIN { if (g > 0) printf "%.0f", a / 1e9 / g; else print "inf" }')
    fi
  else
    prev_alert=0
  fi

  printf '%-15s %3d%% used  %s GB/day  ~%s days left\n' "$path" "$pct" "$growth" "$days"

  alert=0
  reason=""
  if ((pct >= THRESHOLD)); then
    alert=1
    reason="$path is ${pct}% full"
  elif [[ $days != "n/a" && $days != "inf" ]] && ((days < MIN_DAYS)); then
    alert=1
    reason="$path will be full in ~$days days ($growth GB/day)"
  fi
  if ((alert && !prev_alert)); then
    notify "$reason"
  elif ((!alert && prev_alert)); then
    notify "$path recovered: ${pct}% used"
  fi
  echo "$now $used $alert" >"$state_file"
done
