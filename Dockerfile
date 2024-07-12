ARG PG_MAJOR_VERSION=16
FROM postgres:${PG_MAJOR_VERSION} AS pgmq-builder
ARG PG_MAJOR_VERSION
ARG PGMQ_VERSION=v1.3.3

RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      clang \
      curl \
      gcc \
      git \
      libssl-dev \
      make \
      pkg-config \
      postgresql-server-dev-${PG_MAJOR_VERSION}

# Install pgmq and pg_partman
RUN cd /usr/src/ && \
    git clone https://github.com/tembo-io/pgmq.git && \
    cd pgmq && \
    git checkout ${PGMQ_VERSION} && \
    cd pgmq-extension && \
    make && \
    make install && \
    make install-pg-partman

FROM postgres:${PG_MAJOR_VERSION}
ARG PG_MAJOR_VERSION
ARG LIBICU_VERSION=72
ARG PARADEDB_TELEMETRY=false
ARG PGML_LSB_RELEASE_CS=jammy
ENV PARADEDB_TELEMETRY=$PARADEDB_TELEMETRY
ENV TZ=UTC

LABEL maintainer="TKamitaSoft Service - https://tkamitasoft.com" \
      org.opencontainers.image.description="TKamitaSoft PostgrSQL database" \
      org.opencontainers.image.source="https://gitlab.com/tkamitasoft/apps/host"

COPY --from=pgmq-builder /usr/share/postgresql/${PG_MAJOR_VERSION}/extension /usr/share/postgresql/${PG_MAJOR_VERSION}/extension
COPY --from=pgmq-builder /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib
COPY --from=pgmq-builder /usr/src/pgmq/images/pgmq-pg/postgresql.conf /usr/share/postgresql/${PG_MAJOR_VERSION}/postgresql.conf.sample

RUN echo "deb [trusted=yes] https://apt.postgresml.org ${PGML_LSB_RELEASE_CS} main" > /etc/apt/sources.list.d/postgresml.list
# apt-get install -y --no-install-recommends --fix-missing
RUN DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y \
      ca-certificates \
      coreutils \
      gnupg \
      libicu${LIBICU_VERSION} \
      openssl \
      systemd \
      systemd-sysv \
      postgis \
      postgresql-postgis \
      postgresql-${PG_MAJOR_VERSION}-pgvector \
      postgresql-${PG_MAJOR_VERSION}-partman \
      pgcopydb \
      patroni \
      check-patroni \
      postgresql-pgml-${PG_MAJOR_VERSION} \
      pgcat

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -rf /lib/systemd/system/multi-user.target.wants/* \
    && rm -rf /etc/systemd/system/*.wants/* \
    && rm -rf /lib/systemd/system/local-fs.target.wants/* \
    && rm -rf /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -rf /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -rf /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    && rm -rf /lib/systemd/system/systemd-update-utmp*

USER postgres
CMD ["postgres"]