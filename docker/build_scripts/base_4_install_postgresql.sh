#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

sed -i "s/ main.*$/ main/g" /etc/apt/sources.list.d/pgdg.list
apt-get update -y
apt-get install -y postgresql postgresql-server-dev-all postgresql-all libpq-dev
for version in $DEB_PG_SUPPORTED_VERSIONS; do
    apt-get install -y "postgresql-server-dev-${version}"
done
if [ "$DEMO" != "true" ]; then
    for version in $DEB_PG_SUPPORTED_VERSIONS; do
        # create postgis symlinks to make it possible to perform update
        ln -s "postgis-${POSTGIS_VERSION%.*}.so" "/usr/lib/postgresql/${version}/lib/postgis-2.5.so"
    done
fi
# make it possible for cron to work without root
gcc -s -shared -fPIC -o /usr/local/lib/cron_unprivileged.so cron_unprivileged.c
