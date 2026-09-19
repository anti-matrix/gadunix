FROM alpine:edge

RUN apk add --no-cache \
    alpine-sdk build-base git \
    alpine-conf syslinux \
    xorriso squashfs-tools mtools \
    grub-efi grub-bios \
    mkinitfs fakeroot abuild

RUN adduser -D builder && adduser builder abuild

COPY build.sh /usr/local/bin/build-gadunix
RUN chmod +x /usr/local/bin/build-gadunix

ENTRYPOINT ["build-gadunix"]
