#!/bin/bash
#
# This script creates a Root Filesystem suitable to use with Docker.
#
# The original script is stolen from ArchWiki, and modified to work
# for ArchLinux ARM.
#
#  https://wiki.archlinux.org/index.php/Install_from_Existing_Linux
#
# Original script has this comment:
#
#  "This script is inspired on the archbootstrap script."
#
# Contributior: Tobias Blom <tobias.blom@techne-dev.se>
#

set -e
set -x

# You can set the ARCH variable to "arm", "armv6h" (RPi), or "armv7h"
ARCH=armv6h

# Change to the mirror which best fits for you
MIRROR="http://mirror.archlinuxarm.org"

addCustomRepo() {
    [[ $(grep -c arch-rpi-techne "${RFS}/etc/pacman.conf" || true) -eq 0 ]] && {
	cat >> "${RFS}/etc/pacman.conf" <<EOF
[arch-rpi-techne]
Server = http://www.techne-dev.se/arch-rpi-techne
EOF
    }

    return 0
}

###############################################################################
#
#  Variables
#
FIRST_PACKAGE=(filesystem)
BASH_PACKAGES=(glibc ncurses readline bash)
PACMAN_PACKAGES=(acl archlinux-keyring attr bzip2 coreutils curl e2fsprogs expat gnupg gpgme keyutils gcc-libs krb5 libarchive libassuan libgpg-error libgcrypt libssh2 lzo2 openssl pacman xz zlib shadow)

# EXTRA_PACKAGES=(pacman-mirrorlist tar libcap arch-install-scripts util-linux systemd)
PACKAGES=(${FIRST_PACKAGE[*]} ${BASH_PACKAGES[*]} ${PACMAN_PACKAGES[*]})

LIST=$(mktemp archinstall.XXXXXXXXXX)
RFS=RFS
PKGS=pkgs

###############################################################################
#
#  Clean up function
#
cleanUp() {
    rm -f ${LIST};
    for MOUNT_POINT in "dev/pts" "dev" "sys" "proc"; do
	[[ -z $(mount | grep "${RFS}/${MOUNT_POINT}") ]] || \
	    umount "${RFS}/${MOUNT_POINT}"
    done
}

trap cleanUp EXIT SIGHUP SIGINT SIGTERM

###############################################################################
#
#  Functions
#
copyResolvConf() {
    [ -f "/etc/resolv.conf" ] && {
	mkdir -p "${RFS}/etc/";
	install -m0644 "/etc/resolv.conf" "${RFS}/etc/resolv.conf"
    }
    return 0
}

setupMirrorList() {
    mkdir -p "${RFS}/etc/pacman.d/";
    echo "Server = ${MIRROR}/${ARCH}/\$repo" >> "${RFS}/etc/pacman.d/mirrorlist"
    return 0
}

###############################################################################
#
#  Main script
#
mkdir -p "${PKGS}" "${RFS}"

# Create a list of filenames for the arch packages
wget -q -O- "${MIRROR}/${ARCH}/core/" | sed -n "s|.*href=\"\\([^\"]*xz\\)\".*|\\1|p" >> ${LIST}

# Download and extract each package
for PACKAGE in ${PACKAGES[*]}; do
    FILE=$(grep "$PACKAGE-[0-9]" ${LIST} | head -n1)
    [[ -f "${PKGS}/${FILE}" ]] || wget "${MIRROR}/${ARCH}/core/${FILE}" -c -O "${PKGS}/${FILE}"
    xz -dc "${PKGS}/$FILE" | tar x -k -C "${RFS}"
    rm -f "${RFS}/.PKGINFO" "${RFS}/.MTREE" "${RFS}/.INSTALL"
done

# Create mount points
mount -t proc proc "${RFS}/proc/"
mount -t sysfs sys "${RFS}/sys/"
mount -o bind /dev "${RFS}/dev/"
mkdir -p "${RFS}/dev/pts"
mount -t devpts pts "${RFS}/dev/pts/"

# Prepare pacman installation
copyResolvConf
setupMirrorList

# Setup, update, and install pacman. Clean up package cache
chroot "${RFS}" pacman-key --init
chroot "${RFS}" pacman-key --populate archlinux
addCustomRepo
chroot "${RFS}" pacman -Syu --noconfirm pacman --force

# Restore files after installation
for FILE in etc/pacman.conf.pacorig etc/resolv.conf.pacorig etc/pacman.d/mirrorlist.pacorig; do
    rm -f "${RFS}/${FILE}"
done
copyResolvConf

# Clean up
addCustomRepo
chroot "${RFS}" pacman --noconfirm -Sc
