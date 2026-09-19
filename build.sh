#!/bin/sh
set -e

# Generate the abuild signing key (as builder, no prompts)
su builder -c 'abuild-keygen -n -a'
for pub in /home/builder/.config/abuild/*.rsa.pub /home/builder/.abuild/*.rsa.pub; do
    [ -f "$pub" ] && cp "$pub" /etc/apk/keys/
done

# Copy the repo into builder's home (bind mount is root-owned; abuild wants builder)
rm -rf /home/builder/gadunix
cp -a /build/. /home/builder/gadunix/
chown -R builder:builder /home/builder/gadunix

# Build gadunix-base into a local repository
su builder -c 'cd /home/builder/gadunix/packages/gadunix-base && abuild -P /home/builder/repo -r'

# abuild's dep cleanup purges busybox-suid (su); restore it
apk add --no-cache busybox-suid git

# Clone aports and drop in the Gadunix profile + overlay
su builder -c 'git clone --depth=1 https://github.com/alpinelinux/aports.git /home/builder/aports'
cp /home/builder/gadunix/profile/mkimg.gadunix.sh /home/builder/aports/scripts/
cp /home/builder/gadunix/profile/genapkovl.sh  /home/builder/aports/scripts/
cp -a /home/builder/gadunix/overlayfs /home/builder/aports/
sed -i 's/linux-firmware /linux-firmware-none /' /home/builder/aports/scripts/mkimg.base.sh
chown -R builder:builder /home/builder/aports

# Build the ISO (mkimage reads PACKAGER_PRIVKEY from the environment, not abuild.conf)
PRIVKEY=$(sed -n 's/^PACKAGER_PRIVKEY="\(.*\)"$/\1/p' /home/builder/.config/abuild/abuild.conf 2>/dev/null | head -n1)
[ -z "$PRIVKEY" ] && PRIVKEY=$(ls /home/builder/.config/abuild/*.rsa /home/builder/.abuild/*.rsa 2>/dev/null | head -n1)
su builder -c "cd /home/builder/aports && PACKAGER_PRIVKEY='$PRIVKEY' PACKAGER='Gadunix <dev@gadunix.local>' sh scripts/mkimage.sh --profile gadunix --arch x86_64 --outdir /home/builder/iso --repository /home/builder/repo/packages --repository https://dl-cdn.alpinelinux.org/alpine/edge/main --repository https://dl-cdn.alpinelinux.org/alpine/edge/community"

# Copy the ISO back out to the host
mkdir -p /build/iso
rm -f /build/iso/*.iso
cp /home/builder/iso/*.iso /build/iso/
echo "=== Done. Output: ==="
ls -la /build/iso/
