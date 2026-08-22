# Gadunix

A minimal general-purpose Linux distribution built on Alpine Linux.

```
gadunix/
├── profile/
│   ├── mkimg.gadunix.sh        # ISO build profile (goes into aports/scripts/)
│   └── genapkovl.sh            # builds the live-system overlay (goes into aports/scripts/)
├── packages/
│   └── gadunix-base/
│       ├── APKBUILD             # the "identity" meta-package
│       ├── gadunix-release
│       ├── gadunix-welcome
│       └── gadunix-help
├── installer/
│   └── gadunix-install          # interactive disk installer (runs from live ISO)
└── overlayfs/                   # files applied to the live system via the overlay
    └── etc/
        └── apk/
            └── repositories
```

---

## Why Alpine

Alpine uses musl + busybox, so the base system is genuinely tiny (~5MB).
`apk` is fast, the repos are large, and the whole thing is designed to be
minimal without being crippled. Your distro is an opinionated layer on top —
your default package selection, your branding, your installer — not a
from-scratch reimplementation of things Alpine already does well.

---

## 1. Set up a build environment

You need an Alpine Linux machine or VM to build this.
The easiest path: run Alpine in QEMU locally, or use Docker.

### Via Docker (quickest start, no VM needed)

```bash
docker run -it --rm -v $(pwd):/gadunix alpine:edge sh
# Inside the container:
apk add alpine-sdk build-base git xorriso mtools grub-efi grub-bios abuild squashfs-tools mkinitfs
```

### Via QEMU (closer to real build environment)

Download the Alpine standard ISO from https://alpinelinux.org/downloads/
Boot it in QEMU, run setup-alpine, then continue below.

---

## 2. Build the custom meta-package (gadunix-base)

```bash
# Set up abuild (Alpine's package build tool)
abuild-keygen -a -i          # generates your signing key, installs it

# Build the package
cd gadunix/packages/gadunix-base
abuild checksum              # generates real sha256 checksums
abuild -r                    # builds the .apk
```

The built `.apk` lands in `~/packages/`. This is your local package repo.

---

## 3. Build the ISO

```bash
# Clone aports (Alpine's package tree — contains mkimage.sh)
git clone https://github.com/alpinelinux/aports.git
cd aports

# Copy your mkimage profile, overlay generator, and overlay files into place
cp /gadunix/profile/mkimg.gadunix.sh scripts/
cp /gadunix/profile/genapkovl.sh   scripts/
cp -r /gadunix/overlayfs .

# Point mkimage at your local package repo so it can find gadunix-base
sh scripts/mkimage.sh \
    --profile gadunix \
    --arch x86_64 \
    --outdir ~/iso \
    --repository ~/packages/x86_64 \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/community
```

Output: `~/iso/gadunix-x86_64.iso`

---

## 4. Test in QEMU (no real hardware needed)

```bash
# Boot the ISO directly
qemu-system-x86_64 \
    -cdrom ~/iso/gadunix-x86_64.iso \
    -boot d \
    -m 1G \
    -enable-kvm \
    -nographic

# Or boot with a virtual disk to test the installer
qemu-img create -f qcow2 /tmp/gadunix-test.img 8G
qemu-system-x86_64 \
    -cdrom ~/iso/gadunix-x86_64.iso \
    -drive file=/tmp/gadunix-test.img,format=qcow2 \
    -boot d \
    -m 1G \
    -enable-kvm
```

Login as `root` (no password on live ISO unless you set one in post-build).
Run `gadunix-install` to test the installer against the virtual disk.

---

## 5. Run the installer (from live ISO)

```bash
gadunix-install
```

The installer:
- Detects UEFI vs BIOS firmware
- Lists available disks
- Asks for target disk, hostname, timezone, root password
- Creates GPT partition table: boot (EFI or BIOS boot) + swap + ext4 root
- Installs base system via `apk`
- Configures fstab, hostname, timezone, os-release
- Installs GRUB (EFI or BIOS bootloader)
- Enables networking + dhcpcd + sshd services

---

## 6. Hosting your own package repo

Once `gadunix-base` (and any future custom packages) are built, host
the `~/packages/` directory as a static file server — nginx, GitHub Pages,
Cloudflare R2, whatever. Then add it to installed systems' `/etc/apk/repositories`.

Your users can then:
```bash
apk add gadunix-something
```

...and get your packages alongside normal Alpine packages.

---

## Customization reference

| Want to... | Edit this |
|---|---|
| Change default installed packages | `profile/mkimg.gadunix.sh` → `apks=` |
| Add a file to the live system | `overlayfs/` — mirrors the live root filesystem |
| Add distro-specific defaults | `packages/gadunix-base/APKBUILD` → `package()` |
| Add a new custom package | New dir under `packages/`, new `APKBUILD` |
| Change branding/welcome message | `packages/gadunix-base/gadunix-welcome` |
| Change installer behavior | `installer/gadunix-install` |

---

## Rebuilding after changes

```bash
# Rebuild package after APKBUILD changes
cd packages/gadunix-base && abuild -r

# Rebuild ISO (from aports/ directory)
sh scripts/mkimage.sh --profile gadunix --arch x86_64 ...
```

Full ISO rebuilds are fast on Alpine (no Buildroot-style toolchain compile)
— usually a few minutes once the initial `apk` cache is warm.
