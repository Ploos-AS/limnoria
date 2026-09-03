# Limnoria container

Production-oriented OCI packaging for [Limnoria](https://limnoria.net/), maintained by Ploos AS.

Image: `ghcr.io/ploos-as/limnoria`

## Highlights

- Docker and Podman friendly
- `linux/amd64` and `linux/arm64`
- runs as non-root UID/GID `1000:1000`
- persistent Limnoria working directory at `/data`
- `tini` as PID 1 for clean signal handling
- explicit healthcheck that only reports healthy while a `supybot` process is running
- first-run behavior that stays up and prints setup instructions instead of crash-looping
- optional Limnoria HTTP server port `8080` is exposed by the image but never published automatically
- upstream source pinned to an immutable Git commit
- GitHub Actions publishing with SBOM and provenance attestations
- Compose and rootless Podman Quadlet examples

## Tags

- `edge` — current `main`
- `0.1.0` — exact release
- `0.1` — release series
- `latest` — most recent tagged release

`latest` is intentionally not updated by normal `main` builds.

## Quick start with Docker Compose

Create a directory and copy `compose.yaml`, then run the Limnoria wizard:

```sh
mkdir -p data
docker compose run --rm limnoria wizard
```

The wizard writes the bot configuration into `/data`, which maps to `./data` in the example Compose file.

Start the bot afterwards:

```sh
docker compose up -d
docker compose logs -f limnoria
```

If exactly one top-level `*.conf` file exists in `/data`, the container selects it automatically.

If more than one configuration exists, select one explicitly:

```yaml
environment:
  LIMNORIA_CONFIG: MyBot.conf
```

An absolute path is also accepted.

## Docker CLI

Run the wizard:

```sh
docker run --rm -it \
  -v "$PWD/data:/data" \
  ghcr.io/ploos-as/limnoria:0.1.0 wizard
```

Run the configured bot:

```sh
docker run -d \
  --name limnoria \
  --restart unless-stopped \
  -v "$PWD/data:/data" \
  ghcr.io/ploos-as/limnoria:0.1.0
```

## Podman

For SELinux systems, use `:Z` on bind mounts:

```sh
podman run --rm -it \
  -v "$PWD/data:/data:Z" \
  ghcr.io/ploos-as/limnoria:0.1.0 wizard
```

Then:

```sh
podman run -d \
  --name limnoria \
  -v "$PWD/data:/data:Z" \
  ghcr.io/ploos-as/limnoria:0.1.0
```

## Podman Quadlet

A rootless Quadlet example is provided at `quadlet/limnoria.container`.

Install it with:

```sh
mkdir -p ~/.config/containers/systemd ~/.local/share/limnoria
cp quadlet/limnoria.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start limnoria.service
```

Run the wizard separately before starting the service, for example:

```sh
podman run --rm -it \
  -v "$HOME/.local/share/limnoria:/data:Z" \
  ghcr.io/ploos-as/limnoria:0.1.0 wizard
```

## `/data` layout

`/data` is deliberately Limnoria's actual working directory rather than a Ploos-specific abstraction. This preserves upstream behavior for relative paths, configuration files, databases and local plugin directories.

A typical installation may look like:

```text
/data/
├── MyBot.conf
├── MyBot.db
├── logs/
└── plugins/
```

Exact files and directories depend on the choices made in `supybot-wizard` and on enabled plugins.

## First-run behavior

With no `*.conf` in `/data`, the default `run` command prints setup instructions and remains alive in an unconfigured state. It does not continuously restart and flood logs.

The healthcheck remains unhealthy in this state. Once Limnoria is actually running, the healthcheck detects the `supybot` process and reports healthy.

If several top-level `*.conf` files exist, set `LIMNORIA_CONFIG` to choose one.

## Entrypoint commands

The image supports:

```text
run       Start Limnoria using LIMNORIA_CONFIG or the single /data/*.conf file
wizard    Run supybot-wizard in /data
shell     Open /bin/sh
<command> Run an arbitrary command inside the image
```

Examples:

```sh
docker run --rm ghcr.io/ploos-as/limnoria:0.1.0 supybot --version
docker compose run --rm limnoria shell
```

## HTTP server

Limnoria can optionally provide an HTTP server, commonly on port `8080`. The image declares `8080`, but neither the Compose nor Quadlet example publishes it by default.

Only publish the port after deliberately enabling and configuring Limnoria's HTTP functionality. For Compose:

```yaml
ports:
  - "8080:8080"
```

No inbound port is required for normal IRC operation; Limnoria connects outbound to IRC servers.

## Upstream pin

Container `0.1.0` pins Limnoria source to:

```text
ProgVal/Limnoria@ac135083987a3a3121a9ba54f980902b29da10c7
```

That upstream commit is dated 2026-08-31. Python 3.13 is used by default; upstream declares Python 3.9 or newer and includes Python 3.13 in its classifiers at this pin.

The build installs upstream's `requirements.txt` from the same immutable commit. Those transitive dependencies are not independently locked to hashes in `0.1.0`; a future hardening release can add a generated lock file if stronger dependency-level reproducibility is required.

## Build locally

```sh
docker build -t limnoria:local .
```

Override the Python version or upstream source pin when developing:

```sh
docker build \
  --build-arg PYTHON_VERSION=3.13 \
  --build-arg LIMNORIA_REF=ac135083987a3a3121a9ba54f980902b29da10c7 \
  -t limnoria:local .
```

Changing `LIMNORIA_REF` may also require changing `LIMNORIA_SOURCE_DATE_EPOCH` so upstream's generated version remains deterministic.

## Validation

Static checks:

```sh
sh tests/static.sh
```

Build and smoke-test:

```sh
docker build -t limnoria:test .
sh scripts/smoke-test.sh limnoria:test
```

CI performs the same baseline checks before publishing and builds a multi-platform OCI image for `linux/amd64` and `linux/arm64`.

## Security model

The runtime image:

- runs as UID/GID `1000:1000`
- does not require privileged mode
- does not require access to the Docker or Podman socket
- keeps writable application state under `/data`
- uses `tini` for signal forwarding and child reaping

As with any IRC bot, enabled plugins can significantly expand functionality and network access. Only enable plugins and third-party plugin code you trust.

## Plugins

This image ships Limnoria and the dependencies listed by upstream at the pinned commit. Ploos AS does not bundle an additional curated collection of third-party plugins into the base image.

Keeping third-party plugins out of the base image makes upgrades, provenance and support boundaries clearer. Derived images or a separate controlled plugin mechanism can be added later if needed.

## Licenses

The container packaging in this repository is licensed under MIT; see `LICENSE`.

Limnoria is BSD-3-Clause licensed. Its license notice and upstream pin are recorded in `THIRD_PARTY_LICENSES.md`.

This repository is an independent container-packaging project and is not the upstream Limnoria project.
