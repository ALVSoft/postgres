ARG BASE_IMAGE=nvidia/cuda:12.6.0-base-ubuntu22.04
#nvidia/cuda:12.6.0-devel-ubuntu22.04
#ubuntu:22.04
ARG PGVERSION=16
ARG TIMESCALEDB="2.11.2 2.14.2 2.16.1"
ARG DEMO=false
ARG COMPRESS=false
ARG ADDITIONAL_LOCALES=

FROM ubuntu:18.04 AS ubuntu-18

ARG ADDITIONAL_LOCALES

COPY build_scripts/locales.sh /builddeps/

RUN bash /builddeps/locales.sh


FROM $BASE_IMAGE AS dependencies-builder

ARG DEMO

ENV WALG_VERSION=v3.0.3

COPY build_scripts/dependencies.sh /builddeps/

COPY dependencies/debs /builddeps/

RUN bash /builddeps/dependencies.sh


FROM $BASE_IMAGE AS builder

ARG DEMO
ARG ADDITIONAL_LOCALES

COPY build_scripts/prepare.sh build_scripts/locales.sh /builddeps/

RUN bash /builddeps/prepare.sh

COPY --from=ubuntu-18 /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.18

COPY cron_unprivileged.c /builddeps/
COPY build_scripts/base.sh /builddeps/
COPY --from=dependencies-builder /builddeps/*.deb /builddeps/

ARG PGVERSION
ARG TIMESCALEDB
ARG TIMESCALEDB_APACHE_ONLY=true
ARG TIMESCALEDB_TOOLKIT=true
ARG COMPRESS
ARG PGOLDVERSIONS="12 13 14 15"
ARG WITH_PERL=false
ARG DEB_PG_SUPPORTED_VERSIONS="$PGOLDVERSIONS $PGVERSION"
ARG GO_VERSION=1.23.0
ARG PGRX_VERSION12=0.12.1
ARG PGRX_VERSION11=0.11.3

ENV CARGO_HOME="${HOME}/.cargo"
ENV PATH="${PATH}:/usr/local/go/bin:${CARGO_HOME}/bin"

# RUN chown -R postgres:postgres "$HOME"

# Install PostgreSQL, extensions and contribs
ENV POSTGIS_VERSION=3.4 \
    BG_MON_COMMIT=ef60961eff92672b1e21f5260dc1211367da6f1f \
    PG_AUTH_MON_COMMIT=3d010e5959285c32b155e8064c9c9b57869aeca7 \
    PG_MON_COMMIT=a6c5982368edd876edbee01e51b91e7387071e21 \
    SET_USER=REL4_0_1 \
    PLPROFILER=REL4_2_4 \
    PG_PROFILE=4.6 \
    PAM_OAUTH2=v1.0.1 \
    PG_PERMISSIONS_COMMIT=314b9359e3d77c0b2ef7dbbde97fa4be80e31925 \
    PGMQ=v1.4.1 \
    PGROLL=v0.6.0 \
    TEMPORAL_TABLES=v1.2.2 \
    PG_ANALYTICS=v0.1.1 \
    PG_SEARCH=v0.9.1 \
    PG_SEARCH_RELEASE=0.9.1 \
    PGHYDRO=v.6.6 \
    PG_JSONSCHEMA=v0.3.1 \
    PG_UUIDV7=v1.5.0 \
    PG_UUIDV7_RELEASE=1.5 \
    POSTGREST=v12.2.3 \
    PG_GRAPHQL=v1.5.7 \
    PGCAT=v1.1.1

WORKDIR /builddeps
RUN bash base.sh

# Install wal-g
COPY --from=dependencies-builder /builddeps/wal-g /usr/local/bin/

COPY build_scripts/patroni_wale.sh build_scripts/compress_build.sh /builddeps/

# Install patroni and wal-e
ENV PATRONIVERSION=3.3.2
ENV WALE_VERSION=1.1.1

WORKDIR /

RUN bash /builddeps/patroni_wale.sh

RUN if [ "$COMPRESS" = "true" ]; then bash /builddeps/compress_build.sh; fi

COPY pgcat.toml /etc/pgcat/config.toml
COPY postgrest.conf /etc/postgrest/postgrest.conf


FROM builder

LABEL maintainer="ATCHOMBA Luc Vindjedou - <https://www.alvsoft.pro>" \
    org.opencontainers.image.description="PostgrSQL Server with many extention installed." \
    org.opencontainers.image.source="https://github.com/alvsoft/postgres"

ARG PGVERSION
ARG TIMESCALEDB
ARG DEMO
ARG COMPRESS
ARG PARADEDB_TELEMETRY=false
ARG TZ=UTC

EXPOSE 5432 8008 8080

ENV LC_ALL=en_US.utf-8 \
    PATH=$PATH:/usr/lib/postgresql/$PGVERSION/bin \
    PGHOME=/home/postgres \
    RW_DIR=/run \
    TIMESCALEDB=$TIMESCALEDB \
    DEMO=$DEMO \
    PARADEDB_TELEMETRY=$PARADEDB_TELEMETRY \
    TZ=$TZ

ENV WALE_ENV_DIR=$RW_DIR/etc/wal-e.d/env \
    LOG_ENV_DIR=$RW_DIR/etc/log.d/env \
    PGROOT=$PGHOME/pgdata/pgroot

ENV PGDATA=$PGROOT/data \
    PGLOG=$PGROOT/pg_log

ENV USE_OLD_LOCALES=false 

WORKDIR $PGHOME

COPY motd /etc/
COPY runit /etc/service/
COPY pgq_ticker.ini $PGHOME/
COPY build_scripts/post_build.sh /builddeps/

RUN sh /builddeps/post_build.sh && rm -rf /builddeps/

COPY scripts bootstrap major_upgrade /scripts/
COPY launch.sh /

CMD ["/bin/sh", "/launch.sh", "init"]
