#!/bin/sh
set -eu

image="${1:-limnoria:test}"
tmp="$(mktemp -d)"
server_log="$tmp/irc-server.log"
bot_log="$tmp/limnoria.log"
server_pid=''
cid=''

cleanup() {
  [ -z "$cid" ] || docker rm -f "$cid" >/dev/null 2>&1 || true
  [ -z "$server_pid" ] || kill "$server_pid" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

chmod 777 "$tmp"
mkdir -p "$tmp/backup" "$tmp/logs"
chmod 777 "$tmp/backup" "$tmp/logs"

cat > "$tmp/ci.conf" <<'EOF'
supybot.nick: limnoria-ci
supybot.ident: limnoria
supybot.user: Limnoria CI
supybot.networks: test
supybot.networks.test.servers: 127.0.0.1:16667
supybot.networks.test.channels: #ci
supybot.networks.test.ssl: False
supybot.networks.test.sasl.enabled: False
supybot.directories.conf: /data
supybot.directories.data: /data
supybot.directories.backup: /data/backup
supybot.directories.log: /data/logs
supybot.log.level: ERROR
EOF
chmod 666 "$tmp/ci.conf"

python3 tests/irc_stub.py >"$server_log" 2>&1 &
server_pid=$!

for _ in $(seq 1 50); do
  grep -q '^LISTEN ' "$server_log" 2>/dev/null && break
  sleep 0.1
done
grep -q '^LISTEN ' "$server_log"

cid="$(docker run -d --network host -v "$tmp:/data" "$image")"

ok=0
for _ in $(seq 1 200); do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    if wait "$server_pid"; then
      ok=1
    fi
    server_pid=''
    break
  fi
  sleep 0.1
done

if [ "$ok" -ne 1 ]; then
  echo 'IRC integration test failed' >&2
  echo '--- IRC stub log ---' >&2
  cat "$server_log" >&2 || true
  echo '--- Limnoria log ---' >&2
  docker logs "$cid" >"$bot_log" 2>&1 || true
  cat "$bot_log" >&2 || true
  exit 1
fi

grep -q '^REGISTERED$' "$server_log"
grep -q '^JOINED #ci$' "$server_log"
grep -q '^PONG_OK$' "$server_log"

docker stop --time 10 "$cid" >/dev/null
cid=''

echo 'IRC integration test: PASS'
