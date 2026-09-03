# syntax=docker/dockerfile:1.7

ARG PYTHON_VERSION=3.13

FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

ARG LIMNORIA_REF=ac135083987a3a3121a9ba54f980902b29da10c7
ARG LIMNORIA_SOURCE_DATE_EPOCH=1788154024

ENV VIRTUAL_ENV=/opt/limnoria/venv \
    PATH=/opt/limnoria/venv/bin:$PATH \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN python -m venv "$VIRTUAL_ENV" \
    && pip install --upgrade pip setuptools wheel \
    && pip install -r "https://raw.githubusercontent.com/ProgVal/Limnoria/${LIMNORIA_REF}/requirements.txt" \
    && SOURCE_DATE_EPOCH="${LIMNORIA_SOURCE_DATE_EPOCH}" \
       pip install "https://github.com/ProgVal/Limnoria/archive/${LIMNORIA_REF}.tar.gz" \
    && supybot --version

FROM python:${PYTHON_VERSION}-slim-bookworm

ARG VERSION=0.1.0
ARG LIMNORIA_REF=ac135083987a3a3121a9ba54f980902b29da10c7

LABEL org.opencontainers.image.title="Limnoria" \
      org.opencontainers.image.description="Production-oriented OCI image for the Limnoria IRC bot" \
      org.opencontainers.image.url="https://github.com/Ploos-AS/limnoria" \
      org.opencontainers.image.source="https://github.com/Ploos-AS/limnoria" \
      org.opencontainers.image.documentation="https://github.com/Ploos-AS/limnoria#readme" \
      org.opencontainers.image.vendor="Ploos AS" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${LIMNORIA_REF}" \
      org.opencontainers.image.licenses="MIT AND BSD-3-Clause"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 limnoria \
    && useradd --uid 1000 --gid 1000 --home-dir /data --create-home --shell /usr/sbin/nologin limnoria

COPY --from=builder /opt/limnoria/venv /opt/limnoria/venv
COPY rootfs/ /

RUN chmod 0755 /usr/local/bin/limnoria-entrypoint /usr/local/bin/limnoria-healthcheck \
    && chown -R 1000:1000 /data

ENV VIRTUAL_ENV=/opt/limnoria/venv \
    PATH=/opt/limnoria/venv/bin:$PATH \
    HOME=/data \
    PYTHONUNBUFFERED=1

WORKDIR /data
VOLUME ["/data"]
EXPOSE 8080
USER 1000:1000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/limnoria-healthcheck"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/limnoria-entrypoint"]
CMD ["run"]
