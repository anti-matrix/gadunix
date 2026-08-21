#!/bin/sh -e
# genapkovl.sh — build the apk overlay tarball applied to the live system at boot.
#
# Invoked by aports/scripts/mkimage.sh as:
#   fakeroot genapkovl.sh <hostname>
#
# The generated tarball configures the live Gadunix system: hostname,
# basic wired networking, and any files dropped under overlayfs/.

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname" >&2
	exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/etc/network"

# Live hostname
printf '%s\n' "$HOSTNAME" > "$tmp/etc/hostname"

# Basic wired networking so the live system comes up online
cat > "$tmp/etc/network/interfaces" << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Extra files from overlayfs/ (mirrors the live root filesystem).
# Look next to this script first, then allow an explicit override.
OVERLAY="${OVERLAY_DIR:-$(dirname "$0")/../overlayfs}"
if [ -d "$OVERLAY" ]; then
	cp -a "$OVERLAY"/. "$tmp"/
fi

tar -c -C "$tmp" . | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
