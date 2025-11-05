#!/bin/sh
# Copyright 2024-2025 Simon McVittie
# SPDX-License-Identifier: LGPL-2.1-or-later

# Reproducer for <https://bugs.debian.org/1065022>.
# Needs to be run as root in an expendable amd64 chroot, container or VM
# that initially has apt sources that can install some version of
# libglib2.0-0, for example:
# podman run --rm -it -v $(pwd):$(pwd):ro -w $(pwd) debian:bookworm-slim debian/tests/manual/1065022.sh
# podman run --rm -it -v $(pwd):$(pwd):ro -w $(pwd) debian:sid-20240110-slim debian/tests/manual/1065022.sh
#
# To test proposed packages for bookworm and/or trixie, generate a
# Packages file in the directory with the packages
# (dpkg-scanpackages --multiversion . > Packages)
# and add
# -v /proposed-bookworm-debs-here:/mnt/bookworm:ro
# -v /proposed-trixie-debs-here:/mnt/trixie:ro
# to the podman command-line.
#
# Optional argument:
# - 1110696 to reproduce <https://bugs.debian.org/1110696>
# - extra-schema or extra-module to exercise additional safety check added
#   while fixing <https://bugs.debian.org/1110696>

set -eux

export DEBIAN_FRONTEND=noninteractive
n=0
failed=0
this_tuple=x86_64-linux-gnu
other_arch=i386
other_tuple=i386-linux-gnu

assert () {
    n=$(( n + 1 ))

    if "$@"; then
        echo "ok $n - $*"
    else
        echo "not ok $n - $* exit status $?"
        failed=1
    fi
}

# Add a deb822-formatted apt source at this location if you are testing a
# locally-built glib2.0 for bookworm before upload
if [ -e /mnt/bookworm/Packages ]; then
    echo "deb [trusted=yes] file:///mnt/bookworm ./" > /etc/apt/sources.list.d/proposed.list
fi

# Preconditions: install libglib2.0-0, libglib2.0-0t64, at least one
# GSettings schema and at least one GIO module.
dpkg --add-architecture "$other_arch"
apt-get -y update
apt-get -y install libglib2.0-0 "libglib2.0-0:$other_arch"
apt-get -y install gsettings-desktop-schemas
apt-get -y install dconf-gsettings-backend "dconf-gsettings-backend:$other_arch"
test -e /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
test -s /usr/share/glib-2.0/schemas/gschemas.compiled

for tuple in "$this_tuple" "$other_tuple"; do
    f="/usr/lib/$tuple/gio/modules/libdconfsettings.so"
    test -e "$f"
    test -s "$f"
done

for tuple in "$this_tuple" "$other_tuple"; do
    f="/usr/lib/$tuple/gio/modules/giomodule.cache"
    test -e "$f"
    test -s "$f"
done

# Make it visible what the postrm is doing
sed -i -e 's/^set -e$/&x/g' /var/lib/dpkg/info/libglib2.0-0*.postrm || true

# Remove but do not purge the other architecture's packages
apt-get -y remove "libglib2.0-0:$other_arch" "dconf-gsettings-backend:$other_arch"
apt-get -y autoremove

if [ "${1-}" = 1110696 ]; then
    # To reproduce #1110696, completely remove the other architecture
    apt-get -y remove --allow-remove-essential $(dpkg-query -W -f '${binary:Package}\n' | grep :i386)
    dpkg --remove-architecture i386
fi

# Upgrade to trixie with libglib2.0-0t64
cat > /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# Add a deb822-formatted apt source at this location if you are testing a
# locally-built glib2.0 before upload
if [ -e /mnt/trixie/Packages ]; then
    echo "deb [trusted=yes] file:///mnt/trixie ./" > /etc/apt/sources.list.d/proposed.list
fi

# Reproducer (1): Upgrade to libglib2.0-0t64. This runs the postrm from
# libglib2.0-0, which deletes necessary files.
apt-get -y update
apt-get -y install --purge libglib2.0-0t64
sed -i -e 's/^set -e$/&x/g' /var/lib/dpkg/info/libglib2.0-0*.postrm || true

assert test -e /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
assert test -s /usr/share/glib-2.0/schemas/gschemas.compiled

assert test -e "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"
assert test -s "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"

assert test -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"
assert test -s "/usr/lib/$this_tuple/gio/modules/giomodule.cache"

# Workaround: Trigger the postinst of libglib2.0-0t64, which will regenerate
# the generated files.
apt-get -y install --reinstall libglib2.0-0t64
sed -i -e 's/^set -e$/&x/g' /var/lib/dpkg/info/libglib2.0-0*.postrm || true

assert test -e /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
assert test -s /usr/share/glib-2.0/schemas/gschemas.compiled

assert test -e "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"
assert test -s "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"

assert test -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"
assert test -s "/usr/lib/$this_tuple/gio/modules/giomodule.cache"

# Reproducer (2): Purge the other multiarch instance of libglib2.0-0.
# Again this runs the postrm from libglib2.0-0, which deletes necessary files.
# (This is also the relevant part for reproducing #1110696.)
dpkg --purge "libglib2.0-0:$other_arch"

assert test -e /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
# This is the assertion that will fail for #1110696
assert test -s /usr/share/glib-2.0/schemas/gschemas.compiled

assert test -e "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"
assert test -s "/usr/lib/$this_tuple/gio/modules/libdconfsettings.so"

assert test -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"
assert test -s "/usr/lib/$this_tuple/gio/modules/giomodule.cache"

case "${1-}" in
    (extra-schema)
        touch "/usr/share/glib-2.0/schemas/UNPACKAGED.xml"
        ;;
    (extra-module)
        touch "/usr/lib/$this_tuple/gio/modules/UNPACKAGED.so"
        ;;
esac

# Merely removing GLib does not delete the generated files, although
# they might have become empty.
apt-get -y remove libglib2.0-0t64
assert test -e /usr/share/glib-2.0/schemas/gschemas.compiled
assert test -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"

# Purge GLib completely, taking dependent packages with it.
apt-get -y remove --purge libglib2.0-0t64

case "${1-}" in
    (extra-schema)
        # Because /usr/share/glib-2.0/schemas/UNPACKAGED.xml exists,
        # we err on the side of caution and do not remove the compiled
        # schemas.
        assert test -e /usr/share/glib-2.0/schemas/gschemas.compiled
        ;;
    (*)
        # Otherwise, we should remove it during purge.
        assert test ! -e /usr/share/glib-2.0/schemas/gschemas.compiled
        ;;
esac

# As above, but for GIO modules.
case "${1-}" in
    (extra-module)
        assert test -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"
        ;;
    (*)
        assert test ! -e "/usr/lib/$this_tuple/gio/modules/giomodule.cache"
        ;;
esac

echo "1..$n"
exit "$failed"

# vim:set sw=4 sts=4 et:
