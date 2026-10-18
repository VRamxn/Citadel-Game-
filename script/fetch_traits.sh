#!/usr/bin/env bash
# Downloads mainnet CITADEL metadata into data/raw/<id>.json, politely: one request every 2s, honouring Retry-After
# when the Pinata gateway rate-limits. Re-run any time; it only fetches what's missing.
set -u
cd "$(dirname "$0")/../data" && mkdir -p raw
BASE="https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6"
for i in $(seq 0 1023); do
  f="raw/$i.json"
  grep -q attributes "$f" 2>/dev/null && continue
  while :; do
    code=$(curl -s -m 30 -D /tmp/citadel-hdr.$$ -o "$f" -w '%{http_code}' "$BASE/$i")
    if [ "$code" = 200 ] && grep -q attributes "$f"; then break; fi
    wait=$(grep -i '^retry-after:' /tmp/citadel-hdr.$$ | tr -dc '0-9'); wait=${wait:-60}
    echo "$(date +%T) id $i: HTTP $code, waiting ${wait}s"
    sleep "$wait"
  done
  sleep 2
done
rm -f /tmp/citadel-hdr.$$
echo "done: $(grep -l attributes raw/*.json | wc -l) / 1024"
