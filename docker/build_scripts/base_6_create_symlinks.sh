#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

# Try to minimize size by creating symlinks instead of duplicate files
if [ "$DEMO" != "true" ]; then
    cd "/usr/lib/postgresql/$PGVERSION/bin"
    for u in clusterdb \
            pg_archivecleanup \
            pg_basebackup \
            pg_isready \
            pg_recvlogical \
            pg_test_fsync \
            pg_test_timing \
            pgbench \
            reindexdb \
            vacuumlo *.py; do
        for v in /usr/lib/postgresql/*; do
            if [ "$v" != "/usr/lib/postgresql/$PGVERSION" ] && [ -f "$v/bin/$u" ]; then
                rm "$v/bin/$u"
                ln -s "../../$PGVERSION/bin/$u" "$v/bin/$u"
            fi
        done
    done
    set +x
    for v1 in $(find /usr/share/postgresql -type d -mindepth 1 -maxdepth 1 | sort -Vr); do
        # relink files with the same content
        cd "$v1/extension"
        while IFS= read -r -d '' orig
        do
            for f in "${orig%.sql}"--*.sql; do
                if [ ! -L "$f" ] && diff "$orig" "$f" > /dev/null; then
                    echo "creating symlink $f -> $orig"
                    rm "$f" && ln -s "$orig" "$f"
                fi
            done
        done <  <(find . -type f -maxdepth 1 -name '*.sql' -not -name '*--*')
        for e in pgq pgq_node plproxy address_standardizer address_standardizer_data_us; do
            orig=$(basename "$(find . -maxdepth 1 -type f -name "$e--*--*.sql" | head -n1)")
            if [ "x$orig" != "x" ]; then
                for f in "$e"--*--*.sql; do
                    if [ "$f" != "$orig" ] && [ ! -L "$f" ] && diff "$f" "$orig" > /dev/null; then
                        echo "creating symlink $f -> $orig"
                        rm "$f" && ln -s "$orig" "$f"
                    fi
                done
            fi
        done
        # relink files with the same name and content across different major versions
        started=0
        for v2 in $(find /usr/share/postgresql -type d -mindepth 1 -maxdepth 1 | sort -Vr); do
            if [ "$v1" = "$v2" ]; then
                started=1
            elif [ $started = 1 ]; then
                for d1 in extension contrib contrib/postgis-$POSTGIS_VERSION; do
                    if [ -d "$v1/$d1" ]; then
                        cd "$v1/$d1"
                        d2="$d1"
                        d1="../../${v1##*/}/$d1"
                        if [ "${d2%-*}" = "contrib/postgis" ]; then
                            d1="../$d1"
                        fi
                        d2="$v2/$d2"
                        for f in *.html *.sql *.control *.pl; do
                            if [ -f "$d2/$f" ] && [ ! -L "$d2/$f" ] && diff "$d2/$f" "$f" > /dev/null; then
                                echo "creating symlink $d2/$f -> $d1/$f"
                                rm "$d2/$f" && ln -s "$d1/$f" "$d2/$f"
                            fi
                        done
                    fi
                done
            fi
        done
    done
    set -x
fi
