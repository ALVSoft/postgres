#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

# Clean up
rm -rf /var/lib/apt/lists/* \
        /var/cache/debconf/* \
        /builddeps \
        /usr/share/doc \
        /usr/share/man \
        /usr/share/info \
        /usr/share/locale/?? \
        /usr/share/locale/??_?? \
        /usr/share/postgresql/*/man \
        /etc/pgbouncer/* \
        /usr/lib/postgresql/*/bin/createdb \
        /usr/lib/postgresql/*/bin/createlang \
        /usr/lib/postgresql/*/bin/createuser \
        /usr/lib/postgresql/*/bin/dropdb \
        /usr/lib/postgresql/*/bin/droplang \
        /usr/lib/postgresql/*/bin/dropuser \
        /usr/lib/postgresql/*/bin/pg_standby \
        /usr/lib/postgresql/*/bin/pltcl_* \
        /tmp/*
find /var/log -type f -exec truncate --size 0 {} \;
