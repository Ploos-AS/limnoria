#!/bin/sh
set -eu

image="${1:-ghcr.io/ploos-as/limnoria:edge}"

echo "qualifying published image: $image"

raw="$(docker buildx imagetools inspect --raw "$image")"
printf '%s' "$raw" | grep -q '"architecture":"amd64"' || {
  echo 'published image is missing linux/amd64' >&2
  exit 1
}
printf '%s' "$raw" | grep -q '"architecture":"arm64"' || {
  echo 'published image is missing linux/arm64' >&2
  exit 1
}

docker pull "$image" >/dev/null

digest="$(docker image inspect "$image" --format '{{index .RepoDigests 0}}')"
[ -n "$digest" ] || { echo 'published image has no repository digest' >&2; exit 1; }
echo "qualified digest: $digest"

uid="$(docker run --rm --entrypoint id "$image" -u)"
gid="$(docker run --rm --entrypoint id "$image" -g)"
[ "$uid" = '1000' ] || { echo "unexpected uid: $uid" >&2; exit 1; }
[ "$gid" = '1000' ] || { echo "unexpected gid: $gid" >&2; exit 1; }

docker run --rm "$image" supybot --version >/dev/null

docker run --rm --entrypoint sh "$image" -c 'touch /data/.qualification && rm /data/.qualification'

if docker run --rm -e LIMNORIA_CONFIG=missing.conf "$image" >/tmp/limnoria-explicit.out 2>&1; then
  echo 'missing explicit config unexpectedly succeeded' >&2
  cat /tmp/limnoria-explicit.out >&2
  exit 1
else
  rc=$?
fi
[ "$rc" -eq 64 ] || {
  echo "missing explicit config returned $rc, expected 64" >&2
  cat /tmp/limnoria-explicit.out >&2
  exit 1
}
grep -q 'Configured file does not exist: /data/missing.conf' /tmp/limnoria-explicit.out

cid="$(docker run -d "$image")"
cleanup() {
  docker rm -f "$cid" >/dev/null 2>&1 || true
  rm -f /tmp/limnoria-explicit.out
}
trap cleanup EXIT INT TERM

sleep 3
docker inspect -f '{{.State.Running}}' "$cid" | grep -qx true
docker logs "$cid" 2>&1 | grep -q 'Limnoria is not configured yet.'

docker stop --time 10 "$cid" >/dev/null
[ "$(docker inspect -f '{{.State.Running}}' "$cid")" = 'false' ]

trap - EXIT INT TERM
cleanup

echo 'published image qualification: PASS'
