#!/bin/bash
## -------------------------------------------
## Install PostgreSQL, extensions and contribs
## -------------------------------------------

# shellcheck disable=SC1090
. "$VARIABLES_FILE"
apt-get purge -y "${BUILD_PACKAGES[@]}"
apt-get autoremove -y
if [ "$WITH_PERL" != "true" ] || [ "$DEMO" != "true" ]; then
    dpkg -i ./*.deb || apt-get -y -f install
fi
# Remove unnecessary packages
apt-get purge -y \
                libdpkg-perl \
                libperl5.* \
                perl-modules-5.* \
                postgresql \
                postgresql-all \
                postgresql-server-dev-* \
                libpq-dev=* \
                libmagic1 \
                bsdmainutils
apt-get autoremove -y
apt-get clean -y
dpkg -l | grep '^rc' | awk '{print $2}' | xargs apt-get purge -y
