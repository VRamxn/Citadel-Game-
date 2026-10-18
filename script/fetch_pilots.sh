#!/usr/bin/env bash
# Downloads mainnet PILOT metadata (ids 0..1139) into data/pilots/<id>.json, politely, honouring Retry-After.
set -u
cd "$(dirname "$0")/../data" && mkdir -p pilots
BASE="https://gateway.pinata.cloud/ipfs/bafybeihgg5vrez4nq5mmu4tvuqkvwv7sp62dglljup5azrluraeql2ytta"
N=${PILOT_SUPPLY:-1140}
for i in $(seq 0 $((N - 1))); do
  f="pilots/$i.json"
  grep -q attributes "$f" 2>/dev/null && continue
  while :; do
    code=$(curl -s -m 30 -D /tmp/pilot-hdr.$$ -o "$f" -w '%{http_code}' "$BASE/$i")
    if [ "$code" = 200 ] && grep -q attributes "$f"; then break; fi
    wait=$(grep -i "^retry-after:" /tmp/pilot-hdr.$$ | tr -dc "0-9"); wait=${wait:-60}; [ "$wait" -lt 30 ] && wait=30
    echo "$(date +%T) id $i: HTTP $code, waiting ${wait}s"
    sleep "$wait"
  done
  sleep 2
done
rm -f /tmp/pilot-hdr.$$
echo "done: $(grep -l attributes pilots/*.json | wc -l) / $N"
