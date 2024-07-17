ARG PG_MAJOR_VERSION=16
ARG DEBIAN_FRONTEND=noninteractive
ARG PARADEDB_TELEMETRY=false

FROM postgres:${PG_MAJOR_VERSION}

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
      check-patroni

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV BACK_PATH=$PATH
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install pg-trunk
ENV PATH=$BACK_PATH
ENV BACK_PATH=

RUN trunk install \
      postgis \
      pgrouting \
      pghydro \
      pgvector \
      pg_partman \
      pgmq \
      postgresml

RUN cargo uninstall pg-trunk && \
    rustup self uninstall && \
    apt-get clean && \
    apt-get remove curl && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER postgres
CMD ["postgres"]
