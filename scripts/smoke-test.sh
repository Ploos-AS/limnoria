#!/bin/sh
set -eu

image="${1:-limnoria:test}"

uid="$(docker run --rm --entrypoint id "$image" -u)"
[ "$uid" = "1000" ] || { echo "unexpected uid: $uid" >&2; exit 1; }

docker run --rm "$image" supybot --version >/dev/null
docker run --rm "$image" supybot-wizard --help >/dev/null 2>&1 || true

cid="$(docker run -d "$image")"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
sleep 2
docker inspect -f '{{.State.Running}}' "$cid" | grep -qx true

echo 'container smoke test: PASS'
