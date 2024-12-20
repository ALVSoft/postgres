#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------
export DEBIAN_FRONTEND=noninteractive
MAKEFLAGS="-j $(grep -c ^processor /proc/cpuinfo)"
export MAKEFLAGS
ARCH="$(dpkg --print-architecture)"
CODENAME="$(sed </etc/os-release -ne 's/^VERSION_CODENAME=//p')"
set -ex
sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list
apt-get update -y
# apt-get upgrade -y --fix-missing

# Function to install and init pgrx
setting_pgrx() {
    # Fetch extension version for pgrx
    PGRX_VERSION=$(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name=="pgrx") | .version')
    # Check if cargo pgrx is installed
    if ! cargo --list | grep -q 'pgrx' >/dev/null 2>&1; then
        # Install and init pgrx version required by the extension
        cargo install cargo-pgrx --locked --force --version "${PGRX_VERSION}"
        cargo pgrx init "--pg$version=$PG_CONFIG"
    else
        # Check if the required version of pgrx is installed
        PGRX_VERSION_INSTALLED=$(cargo pgrx --version | awk '{print $2}')
        if [[ "$PGRX_VERSION_INSTALLED" != "$PGRX_VERSION" ]]; then
            # Install and init pgrx version required by the extension
            cargo install cargo-pgrx --locked --force --version "${PGRX_VERSION}"
            cargo pgrx init "--pg$version=$PG_CONFIG"
        fi
    fi
}
BUILD_PACKAGES=(devscripts equivs build-essential fakeroot debhelper git gcc libc6-dev make cmake libevent-dev libbrotli-dev libssl-dev libkrb5-dev)
if [ "$DEMO" = "true" ]; then
    export DEB_PG_SUPPORTED_VERSIONS="$PGVERSION"
    WITH_PERL=false
    rm -f ./*.deb
    apt-get install -y --no-install-recommends "${BUILD_PACKAGES[@]}"

    git config --global http.postBuffer 157286400
else
    BUILD_PACKAGES+=(zlib1g-dev
                    libprotobuf-c-dev
                    libpam0g-dev
                    libcurl4
                    libcurl4-openssl-dev
                    libicu-dev
                    libc-ares-dev
                    pandoc
                    pkg-config
                    software-properties-common
                    dirmngr
                    jq)
    apt-get install -y --no-install-recommends "${BUILD_PACKAGES[@]}" r-base
    
    git config --global http.postBuffer 157286400

    rm -rf /usr/local/go && curl -sL "https://go.dev/dl/go$GO_VERSION.linux-$ARCH.tar.gz" | tar -xz -C /usr/local
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -q -y --profile minimal --default-toolchain stable
    rustup component add llvm-tools-preview
    add-apt-repository -y universe
    add-apt-repository -y ppa:groonga/ppa
    curl -sL "https://packages.groonga.org/ubuntu/groonga-apt-source-latest-$CODENAME.deb" -o "/tmp/groonga-apt-source-latest-$CODENAME.deb"
    apt-get install -y "/tmp/groonga-apt-source-latest-$CODENAME.deb"
    echo "deb [trusted=yes] https://apt.postgresml.org $CODENAME main" > /etc/apt/sources.list.d/postgresml.list
    apt-get update -y
    # install pam_oauth2.so
    git clone -b "$PAM_OAUTH2" --recurse-submodules https://github.com/zalando-pg/pam-oauth2.git
    make -C pam-oauth2 install
    # prepare 3rd sources
    git clone -b "$PLPROFILER" https://github.com/bigsql/plprofiler.git /tmp/plprofiler
    curl -sL "https://github.com/zalando-pg/pg_mon/archive/$PG_MON_COMMIT.tar.gz" | tar -xz -C /tmp
    git clone -b "$PLPRQL" https://github.com/kaspermarstal/plprql.git /tmp/plprql
    git clone -b "$PGMQ" https://github.com/tembo-io/pgmq.git /tmp/pgmq
    git clone -b "$TEMPORAL_TABLES" https://github.com/arkhipov/temporal_tables.git /tmp/temporal_tables
    # git clone -b "$PG_ANALYTICS" --recurse-submodules https://github.com/paradedb/pg_analytics.git /tmp/pg_analytics
    curl -sL "https://github.com/pghydro/pghydro/archive/refs/tags/$PGHYDRO.tar.gz" | tar -xz -C /tmp
    git clone https://github.com/pjungwir/aggs_for_vecs.git /tmp/aggs_for_vecs
    git clone -b "$PG_JSONSCHEMA" https://github.com/supabase/pg_jsonschema.git /tmp/pg_jsonschema
    curl -sL "https://github.com/fboulnois/pg_uuidv7/releases/download/$PG_UUIDV7/pg_uuidv7.tar.gz" | tar -xz -C /tmp --one-top-level=pg_uuidv7
    curl -sL "https://github.com/fboulnois/pg_uuidv7/releases/download/$PG_UUIDV7/SHA256SUMS" --output /tmp/pg_uuidv7/SHA256SUMS
    ( cd /tmp/pg_uuidv7 && sha256sum --ignore-missing --check --quiet SHA256SUMS )
    git clone -b "$PG_GRAPHQL" https://github.com/supabase/pg_graphql.git /tmp/pg_graphql
    git clone -b "$PGCAT" https://github.com/postgresml/pgcat.git /tmp/pgcat
    for p in python3-keyring python3-docutils ieee-data; do
        version=$(apt-cache show $p | sed -n 's/^Version: //p' | sort -rV | head -n 1)
        printf "Section: misc\nPriority: optional\nStandards-Version: 3.9.8\nPackage: %s\nVersion: %s\nDescription: %s" "$p" "$version" "$p" > "$p"
        equivs-build "$p"
    done
fi
echo '#!/bin/bash' > "$VARIABLES_FILE"
echo "BUILD_PACKAGES=(${BUILD_PACKAGES[*]})" >> "$VARIABLES_FILE"
chmod ug+rwx "$VARIABLES_FILE"
if [ "$WITH_PERL" != "true" ]; then
    version=$(apt-cache show perl | sed -n 's/^Version: //p' | sort -rV | head -n 1)
    printf "Priority: standard\nStandards-Version: 3.9.8\nPackage: perl\nMulti-Arch: allowed\nReplaces: perl-base, perl-modules\nVersion: %s\nDescription: perl" "$version" > perl
    equivs-build perl
fi
curl -sL "https://github.com/zalando-pg/bg_mon/archive/$BG_MON_COMMIT.tar.gz" | tar -xz -C /tmp
curl -sL "https://github.com/zalando-pg/pg_auth_mon/archive/$PG_AUTH_MON_COMMIT.tar.gz" | tar -xz -C /tmp
curl -sL "https://github.com/cybertec-postgresql/pg_permissions/archive/$PG_PERMISSIONS_COMMIT.tar.gz" | tar -xz -C /tmp
curl -sL "https://github.com/zubkov-andrei/pg_profile/archive/$PG_PROFILE.tar.gz" | tar -xz -C /tmp
git clone -b "$SET_USER" https://github.com/pgaudit/set_user.git /tmp/set_user
git clone https://github.com/timescale/timescaledb.git /tmp/timescaledb
apt-get install -y \
    postgresql-common \
    libevent-2.1 \
    libevent-pthreads-2.1 \
    brotli \
    libbrotli1 \
    python3.10 \
    python3-psycopg2
