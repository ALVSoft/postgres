ARG BASE_IMAGE=nvidia/cuda:12.6.0-base-ubuntu22.04
#nvidia/cuda:12.6.0-devel-ubuntu22.04
#ubuntu:22.04
ARG PGVERSION=16
ARG TIMESCALEDB="2.15.3 2.17.2"
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
COPY build_scripts/base_1_prepare.sh /builddeps/
COPY build_scripts/base_2_install_relative_extensions.sh /builddeps/
COPY build_scripts/base_3_install_global_extensions.sh /builddeps/
COPY build_scripts/base_4_install_postgresql.sh /builddeps/
COPY build_scripts/base_5_purge.sh /builddeps/
COPY build_scripts/base_6_create_symlinks.sh /builddeps/
COPY build_scripts/base_7_clean.sh /builddeps/
COPY --from=dependencies-builder /builddeps/*.deb /builddeps/

ARG PGVERSION
ARG TIMESCALEDB
ARG TIMESCALEDB_APACHE_ONLY=true
ARG TIMESCALEDB_TOOLKIT=true
ARG COMPRESS
ARG PGOLDVERSIONS="14 15"
ARG WITH_PERL=false

ARG DEB_PG_SUPPORTED_VERSIONS="$PGOLDVERSIONS $PGVERSION"
ARG GO_VERSION=1.23.0

ENV VARIABLES_FILE="/tmp/variables.sh"
ENV CARGO_HOME="${HOME}/.cargo"
ENV PATH="${PATH}:/usr/local/go/bin:${CARGO_HOME}/bin"

# Install PostgreSQL, extensions and contribs
ENV POSTGIS_VERSION=3.5 \
    BG_MON_COMMIT=7f5887218790b263fe3f42f85f4ddc9c8400b154 \
    PG_AUTH_MON_COMMIT=fe099eef7662cbc85b0b79191f47f52f1e96b779 \
    PG_MON_COMMIT=ead1de70794ed62ca1e34d4022f6165ff36e9a91 \
    SET_USER=REL4_1_0 \
    PLPROFILER=REL4_2_5 \
    PG_PROFILE=4.7 \
    PAM_OAUTH2=v1.0.1 \
    PG_PERMISSIONS_COMMIT=f4b7c18676fa64236a1c8e28d34a35764e4a70e2 \
    PGMQ=v1.4.5 \
    PGROLL=v0.8.0 \
    TEMPORAL_TABLES=v1.2.2 \
    # PG_ANALYTICS=v0.2.3 \
    # PG_SEARCH=v0.13.1 \
    # PG_SEARCH_RELEASE=0.13.1 \
    PGHYDRO=v.6.6 \
    PG_JSONSCHEMA=v0.3.3 \
    PG_UUIDV7=v1.6.0 \
    PG_UUIDV7_RELEASE=1.6 \
    POSTGREST=v12.2.3 \
    PG_GRAPHQL=v1.5.9 \
    PGCAT=pgcat-0.2.5 \
    PLPRQL=v1.0.0

WORKDIR /builddeps
RUN bash base_1_prepare.sh
RUN bash base_2_install_relative_extensions.sh
RUN bash base_3_install_global_extensions.sh
RUN bash base_4_install_postgresql.sh
RUN bash base_5_purge.sh
RUN bash base_6_create_symlinks.sh
RUN bash base_7_clean.sh

# Install wal-g
COPY --from=dependencies-builder /builddeps/wal-g /usr/local/bin/

COPY build_scripts/patroni_wale.sh build_scripts/compress_build.sh /builddeps/

# Install patroni and wal-e
ENV PATRONIVERSION=4.0.4
ENV WALE_VERSION=1.1.1

WORKDIR /

RUN bash /builddeps/patroni_wale.sh

# COPY pgcat.toml /etc/pgcat/config.toml
# COPY postgrest.conf /etc/postgrest/postgrest.conf

RUN if [ "$COMPRESS" = "true" ]; then bash /builddeps/compress_build.sh; fi

FROM builder

LABEL maintainer="ATCHOMBA Luc Vindjedou - <https://www.alvsoft.pro>" \
    org.opencontainers.image.description="PostgrSQL Server with many extention installed." \
    org.opencontainers.image.source="https://github.com/alvsoft/postgres"

ARG PGVERSION
ARG TIMESCALEDB
ARG DEMO
ARG COMPRESS
# ARG PARADEDB_TELEMETRY=false
ARG TZ=UTC

EXPOSE 5432 8008 8080 3000 4000

ENV LC_ALL=en_US.utf-8 \
    PATH=$PATH:/usr/lib/postgresql/$PGVERSION/bin \
    PGHOME=/home/postgres \
    RW_DIR=/run \
    TIMESCALEDB=$TIMESCALEDB \
    DEMO=$DEMO \
    # PARADEDB_TELEMETRY=$PARADEDB_TELEMETRY \
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
