#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

# forbid creation of a main cluster when package is installed
sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf
for version in $DEB_PG_SUPPORTED_VERSIONS; do
    PG_CONFIG="/usr/lib/postgresql/$version/bin/pg_config" 
    sed -i "s/ main.*$/ main $version/g" /etc/apt/sources.list.d/pgdg.list
    apt-get update -y
    if [ "$DEMO" != "true" ]; then
        EXTRAS=("postgresql-pltcl-${version}"
                "postgresql-${version}-plr"
                "postgresql-${version}-dirtyread"
                "postgresql-${version}-extra-window-functions"
                "postgresql-${version}-first-last-agg"
                "postgresql-${version}-hll"
                "postgresql-${version}-hypopg"
                "postgresql-${version}-plproxy"
                "postgresql-${version}-partman"
                "postgresql-${version}-pgaudit"
                "postgresql-${version}-pldebugger"
                "postgresql-${version}-pglogical"
                "postgresql-${version}-pglogical-ticker"
                "postgresql-${version}-plpgsql-check"
                "postgresql-${version}-pg-checksums"
                "postgresql-${version}-pgl-ddl-deploy"
                "postgresql-${version}-pgq-node"
                "postgresql-${version}-postgis-${POSTGIS_VERSION%.*}"
                "postgresql-${version}-postgis-${POSTGIS_VERSION%.*}-scripts"
                "postgresql-${version}-pgrouting"
                "postgresql-${version}-repack"
                "postgresql-${version}-wal2json"
                "postgresql-${version}-decoderbufs"
                "postgresql-${version}-pllua"
                "postgresql-${version}-pgvector"
                "postgresql-${version}-pgdg-pgroonga"
                "postgresql-${version}-age"
                "postgresql-pgml-${version}")
        if [ "$WITH_PERL" = "true" ]; then
            EXTRAS+=("postgresql-plperl-${version}")
        fi
    fi
    # Install PostgreSQL binaries, contrib, plproxy and multiple pl's
    apt-get install --allow-downgrades -y \
        "postgresql-${version}-cron" \
        "postgresql-contrib-${version}" \
        "postgresql-${version}-pgextwlist" \
        "postgresql-plpython3-${version}" \
        "postgresql-server-dev-${version}" \
        "postgresql-${version}-pgq3" \
        "postgresql-${version}-pg-stat-kcache" \
        "${EXTRAS[@]}"
    if [ "$DEMO" != "true" ] && [ -f "/etc/postgresql/${version}/main/environment" ]; then
        echo "R_HOME=${R.home(component="home")}" >> "/etc/postgresql/${version}/main/environment"
    fi
    # Install 3rd party stuff
    # use subshell to avoid having to cd back (SC2103)
    (
        cd /tmp/timescaledb
        for v in $TIMESCALEDB; do
            git checkout "$v"
            sed -i "s/VERSION 3.11/VERSION 3.10/" CMakeLists.txt
            if BUILD_FORCE_REMOVE=true ./bootstrap -DREGRESS_CHECKS=OFF -DWARNINGS_AS_ERRORS=OFF \
                    -DTAP_CHECKS=OFF -DPG_CONFIG="/usr/lib/postgresql/$version/bin/pg_config" \
                    -DAPACHE_ONLY="$TIMESCALEDB_APACHE_ONLY" -DSEND_TELEMETRY_DEFAULT=NO; then
                make -C build install
                strip /usr/lib/postgresql/"$version"/lib/timescaledb*.so
            fi
            git reset --hard
            git clean -f -d
        done
    )
    if [ "${TIMESCALEDB_APACHE_ONLY}" != "true" ] && [ "${TIMESCALEDB_TOOLKIT}" = "true" ]; then
        echo "deb [signed-by=/usr/share/keyrings/timescale_E7391C94080429FF.gpg] https://packagecloud.io/timescale/timescaledb/ubuntu/ ${CODENAME} main" | tee /etc/apt/sources.list.d/timescaledb.list
        curl -L https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /usr/share/keyrings/timescale_E7391C94080429FF.gpg
        apt-get update -y
        if [ "$(apt-cache search --names-only "^timescaledb-toolkit-postgresql-${version}$" | wc -l)" -eq 1 ]; then
            apt-get install -y "timescaledb-toolkit-postgresql-$version"
        else
            echo "Skipping timescaledb-toolkit-postgresql-$version as it's not found in the repository"
        fi
        rm /etc/apt/sources.list.d/timescaledb.list
        rm /usr/share/keyrings/timescale_E7391C94080429FF.gpg
    fi
    EXTRA_EXTENSIONS=()
    if [ "$DEMO" != "true" ]; then
        EXTRA_EXTENSIONS+=("/tmp/plprofiler" "/tmp/pg_mon-${PG_MON_COMMIT}")
    fi
    for n in /tmp/bg_mon-${BG_MON_COMMIT} \
            /tmp/pg_auth_mon-${PG_AUTH_MON_COMMIT} \
            /tmp/set_user \
            /tmp/pg_permissions-${PG_PERMISSIONS_COMMIT} \
            /tmp/pg_profile-${PG_PROFILE} \
            "${EXTRA_EXTENSIONS[@]}"; do
        make -C "$n" USE_PGXS=1 clean install-strip
    done
    if [ "$DEMO" != "true" ]; then
        make -C "/tmp/pgmq/pgmq-extension" PG_CONFIG="$PG_CONFIG"
        make -C "/tmp/pgmq/pgmq-extension" install PG_CONFIG="$PG_CONFIG"
        make -C "/tmp/temporal_tables" PG_CONFIG="$PG_CONFIG"
        make -C "/tmp/temporal_tables" install PG_CONFIG="$PG_CONFIG"
        # curl -sL "https://github.com/paradedb/paradedb/releases/download/$PG_SEARCH/postgresql-$version-pg-search_$PG_SEARCH_RELEASE-1PARADEDB-${CODENAME}_$ARCH.deb" --output "/tmp/pg_search_${version}.deb"
        # apt-get install -y "/tmp/pg_search_${version}.deb"
        mkdir -p "/usr/share/postgresql/$version/extension"
        find "/tmp/pghydro-${PGHYDRO}" -type f \( -name '*.sql' -or -name '*.control' \) -print0 | xargs -0 cp -t "/usr/share/postgresql/$version/extension"
        make -C "/tmp/aggs_for_vecs" PG_CONFIG="$PG_CONFIG"
        make -C "/tmp/aggs_for_vecs" install PG_CONFIG="$PG_CONFIG"
        cp "/tmp/pg_uuidv7/$version/pg_uuidv7.so" "/usr/lib/postgresql/$version/lib"
        cp "/tmp/pg_uuidv7/pg_uuidv7--$PG_UUIDV7_RELEASE.sql" "/tmp/pg_uuidv7/pg_uuidv7.control" "/usr/share/postgresql/$version/extension"
        (
            cd /tmp/pg_jsonschema
            setting_pgrx
            cargo pgrx install --pg-config="$PG_CONFIG" --release
        )
        (
            cd /tmp/pg_graphql
            setting_pgrx
            cargo pgrx install --pg-config="$PG_CONFIG" --release
        )
        (
            cd /tmp/plprql/plprql
            setting_pgrx
            cargo pgrx install --no-default-features --pg-config="$PG_CONFIG" --release
        )
        # (
        #     cd /tmp/pg_analytics
        #     setting_pgrx
        #     cargo pgrx install --pg-config="$PG_CONFIG" --release
        # )
        mkdir -p .duckdb/ && chmod -R a+rwX .duckdb/
        mkdir -p /var/lib/postgresql/.duckdb/ && chmod -R a+rwX /var/lib/postgresql/.duckdb/
    fi
done
