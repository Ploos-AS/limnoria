#!/bin/sh
set -eu

required='Dockerfile README.md VERSION requirements.lock compose.yaml quadlet/limnoria.container rootfs/usr/local/bin/limnoria-entrypoint rootfs/usr/local/bin/limnoria-healthcheck docs/releases/v0.1.0.md'
for path in $required; do
  [ -f "$path" ] || { echo "missing: $path" >&2; exit 1; }
done

grep -q 'USER 1000:1000' Dockerfile
grep -q 'VOLUME \["/data"\]' Dockerfile
grep -q 'tini' Dockerfile
grep -q 'ac135083987a3a3121a9ba54f980902b29da10c7' Dockerfile
grep -q 'COPY requirements.lock' Dockerfile
grep -q 'pip install --no-deps -r /tmp/requirements.lock' Dockerfile
grep -q 'pip install --no-deps --no-build-isolation' Dockerfile
grep -q 'pip check' Dockerfile
grep -q '^cryptography==50\.0\.1$' requirements.lock
grep -q '^pyxmpp2-scram==2\.0\.2$' requirements.lock
grep -q 'ghcr.io/ploos-as/limnoria:0.1.0' compose.yaml
grep -q 'Volume=%h/.local/share/limnoria:/data:Z' quadlet/limnoria.container
grep -q '^0\.1\.0$' VERSION
grep -q 'ghcr.io/ploos-as/limnoria:0.1.0' docs/releases/v0.1.0.md
grep -q 'gh release create' .github/workflows/container.yml

# Every active requirement in the lock must be an exact package==version pin.
# Ignore blank lines and full-line comments before validating requirements.
if awk '
  /^[[:space:]]*($|#)/ { next }
  $0 !~ /^[A-Za-z0-9_.-]+==[^[:space:]]+$/ { bad = 1; print "invalid lock line: " $0 > "/dev/stderr" }
  END { exit bad ? 1 : 0 }
' requirements.lock; then
  :
else
  echo 'requirements.lock contains a non-exact dependency' >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose config >/dev/null
fi

echo 'static validation: PASS'
