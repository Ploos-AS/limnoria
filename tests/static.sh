#!/bin/sh
set -eu

required='Dockerfile README.md VERSION compose.yaml quadlet/limnoria.container rootfs/usr/local/bin/limnoria-entrypoint rootfs/usr/local/bin/limnoria-healthcheck docs/releases/v0.1.0.md'
for path in $required; do
  [ -f "$path" ] || { echo "missing: $path" >&2; exit 1; }
done

grep -q 'USER 1000:1000' Dockerfile
grep -q 'VOLUME \["/data"\]' Dockerfile
grep -q 'tini' Dockerfile
grep -q 'ac135083987a3a3121a9ba54f980902b29da10c7' Dockerfile
grep -q 'ghcr.io/ploos-as/limnoria:0.1.0' compose.yaml
grep -q 'Volume=%h/.local/share/limnoria:/data:Z' quadlet/limnoria.container
grep -q '^0\.1\.0$' VERSION
grep -q 'ghcr.io/ploos-as/limnoria:0.1.0' docs/releases/v0.1.0.md
grep -q 'gh release create' .github/workflows/container.yml

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose config >/dev/null
fi

echo 'static validation: PASS'
