#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

apt-get install -y skytools3-ticker pgbouncer
if [ "$DEMO" != "true" ]; then
    apt-get install -y pgagent pgbackrest postgresml-python
    (
        cd /tmp/pgcat
        cargo build --release
        cp target/release/pgcat /usr/bin/pgcat
    )
    go install github.com/xataio/pgroll@"$PGROLL"
    curl -sL "https://github.com/PostgREST/postgrest/releases/download/$POSTGREST/postgrest-$POSTGREST-ubuntu-aarch64.tar.xz" | tar -Jx -C /usr/bin
fi
