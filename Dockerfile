ARG PG_MAJOR_VERSION=16
ARG DEBIAN_FRONTEND=noninteractive
ARG PARADEDB_TELEMETRY=false

FROM postgres:${PG_MAJOR_VERSION}

ARG PG_MAJOR_VERSION
ARG DEBIAN_FRONTEND
ARG PARADEDB_TELEMETRY
ENV PARADEDB_TELEMETRY=$PARADEDB_TELEMETRY
ENV TZ=UTC

LABEL maintainer="ATCHOMBA Luc Vindjedou - https://www.alvsoft.pro" \
      org.opencontainers.image.description="PostgrSQL Server with many extention installed." \
      org.opencontainers.image.source="https://github.com/alvsoft/postgres"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      pgcopydb \
      patroni \
      check-patroni && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    cargo install pg-trunk && \
    trunk install \
      postgis \
      pgrouting \
      pghydro \
      pgvector \
      pg_partman \
      pgmq \
      postgresml && \
    cargo uninstall pg-trunk && \
    rustup self uninstall && \
    apt-get clean && \
    apt-get remove curl && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER postgres
CMD ["postgres"]
