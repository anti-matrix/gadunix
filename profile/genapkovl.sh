#!/bin/sh -e
# genapkovl.sh — build the apk overlay tarball applied to the live system at boot.
#
# Invoked by aports/scripts/mkimage.sh as:
#   fakeroot genapkovl.sh <hostname>
#
# Configures the live Gadunix system: hostname, boot services, wired networking,
# and any files dropped under overlayfs/.

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname" >&2
	exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

rc_add() {
	mkdir -p "$tmp/etc/runlevels/$2"
	ln -sf /etc/init.d/"$1" "$tmp/etc/runlevels/$2/$1"
}

mkdir -p "$tmp/etc/network" "$tmp/etc/apk"

# Live hostname
printf '%s\n' "$HOSTNAME" > "$tmp/etc/hostname"

# Base package set
printf 'alpine-base\n' > "$tmp/etc/apk/world"

# Basic wired networking so the live system comes up online
cat > "$tmp/etc/network/interfaces" << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Boot services (mirrors the standard Alpine live profile)
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

# Extra files from overlayfs/ (mirrors the live root filesystem).
# Look next to this script first, then allow an explicit override.
OVERLAY="${OVERLAY_DIR:-$(dirname "$0")/../overlayfs}"
if [ -d "$OVERLAY" ]; then
	cp -a "$OVERLAY"/. "$tmp"/
fi

tar -c -C "$tmp" . | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
