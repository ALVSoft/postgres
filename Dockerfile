ARG PG_MAJOR_VERSION=16
ARG DEBIAN_FRONTEND=noninteractive
ARG PARADEDB_TELEMETRY=false

FROM postgres:${PG_MAJOR_VERSION} AS builder
ARG PG_MAJOR_VERSION
ARG DEBIAN_FRONTEND
ARG PARADEDB_TELEMETRY
ARG LIBICU_VERSION=72
ARG PGML_LSB_RELEASE_CS=jammy 

RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      clang \
      coreutils \
      curl \
      gcc \
      git \
      gnupg \
      libicu${LIBICU_VERSION} \
      libssl-dev \
      make \
      openssl \
      pkg-config \
      postgresql-server-dev-${PG_MAJOR_VERSION} \
      postgis \
      postgresql-postgis \
      postgresql-${PG_MAJOR_VERSION}-pgvector \
      postgresql-${PG_MAJOR_VERSION}-partman \
      pgcopydb \
      patroni \
      check-patroni && \
    cd /usr/src/ && \
    git clone https://github.com/tembo-io/pgmq.git && \
    cd pgmq/pgmq-extension && \
    make && \
    make install && \
    #make install-pg-partman
    echo "deb [trusted=yes] https://apt.postgresml.org ${PGML_LSB_RELEASE_CS} main" > /etc/apt/sources.list.d/postgresml.list && \
    apt-get update && \
    apt-get install -y \
      postgresql-pgml-${PG_MAJOR_VERSION}

FROM postgres:${PG_MAJOR_VERSION}
ARG PG_MAJOR_VERSION
ARG DEBIAN_FRONTEND
ARG PARADEDB_TELEMETRY
ENV PARADEDB_TELEMETRY=$PARADEDB_TELEMETRY
ENV TZ=UTC

LABEL maintainer="TKamitaSoft Service - https://tkamitasoft.com" \
      org.opencontainers.image.description="TKamitaSoft PostgrSQL database" \
      org.opencontainers.image.source="https://gitlab.com/tkamitasoft/apps/host"

COPY --from=builder /usr/share/postgresql/${PG_MAJOR_VERSION}/extension /usr/share/postgresql/${PG_MAJOR_VERSION}/extension
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib
COPY --from=builder /usr/src/pgmq/images/pgmq-pg/postgresql.conf /usr/share/postgresql/${PG_MAJOR_VERSION}/postgresql.conf.sample

# apt-get install -y --no-install-recommends --fix-missing
RUN apt-get update && \
    apt-get install -y \
      ca-certificates

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER postgres
CMD ["postgres"]
