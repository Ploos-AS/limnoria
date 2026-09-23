# syntax=docker/dockerfile:1.7

ARG PYTHON_VERSION=3.13.15
FROM python:${PYTHON_VERSION}-alpine3.24@sha256:8a6c5efbf700a149072e3e0c39678a093a675a60e7fa607f6c9011f335b0b24b AS builder

ARG LIMNORIA_REF=ac135083987a3a3121a9ba54f980902b29da10c7
ARG LIMNORIA_SOURCE_DATE_EPOCH=1788154024

ENV VIRTUAL_ENV=/opt/limnoria/venv \
    PATH=/opt/limnoria/venv/bin:$PATH \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.lock /tmp/requirements.lock

RUN python -m venv "$VIRTUAL_ENV" \
    && pip install --upgrade 'pip==26.2.1' 'setuptools==84.0.0' 'wheel==0.48.0' 'packaging==26.3' \
    && pip install --no-deps -r /tmp/requirements.lock \
    && SOURCE_DATE_EPOCH="${LIMNORIA_SOURCE_DATE_EPOCH}" \
       pip install --no-deps --no-build-isolation "https://github.com/ProgVal/Limnoria/archive/${LIMNORIA_REF}.tar.gz" \
    && pip check \
    && supybot --version

FROM python:${PYTHON_VERSION}-alpine3.24@sha256:8a6c5efbf700a149072e3e0c39678a093a675a60e7fa607f6c9011f335b0b24b

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

RUN apk add --no-cache ca-certificates tini \
    && addgroup -g 1000 -S limnoria \
    && adduser -u 1000 -S -D -h /data -s /sbin/nologin -G limnoria limnoria

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

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/limnoria-entrypoint"]
CMD ["run"]
