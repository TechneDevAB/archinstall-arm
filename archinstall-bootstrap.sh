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

###############################################################################
#
#  Variables
#
FIRST_PACKAGE=(filesystem)
BASH_PACKAGES=(glibc ncurses readline bash)
PACMAN_PACKAGES=(acl archlinux-keyring attr bzip2 coreutils curl e2fsprogs expat gnupg gpgme keyutils gcc-libs krb5 libarchive libassuan libgpg-error libgcrypt libssh2 lzo2 openssl pacman xz zlib)

# EXTRA_PACKAGES=(pacman-mirrorlist tar libcap arch-install-scripts util-linux systemd)
PACKAGES=(${FIRST_PACKAGE[*]} ${BASH_PACKAGES[*]} ${PACMAN_PACKAGES[*]})

LIST=$(mktemp archinstall.XXXXXXXXXX)
CHROOT_DIR=archinstall-chroot
DIR=archinstall-pkg

###############################################################################
#
#  Clean up function
#
cleanUp() {
    rm -f ${LIST};
    for MOUNT_POINT in "dev/pts" "dev" "sys" "proc"; do
	[[ -z $(mount | grep "${CHROOT_DIR}/${MOUNT_POINT}") ]] || \
	    umount "${CHROOT_DIR}/${MOUNT_POINT}"
    done
}

trap cleanUp EXIT SIGHUP SIGINT SIGTERM

###############################################################################
#
#  Main script
#
mkdir -p "${DIR}" "${CHROOT_DIR}"

# Create a list of filenames for the arch packages
wget -q -O- "${MIRROR}/${ARCH}/core/" | sed -n "s|.*href=\"\\([^\"]*xz\\)\".*|\\1|p" >> ${LIST}

# Download and extract each package
for PACKAGE in ${PACKAGES[*]}; do
    FILE=$(grep "$PACKAGE-[0-9]" ${LIST} | head -n1)
    wget "${MIRROR}/${ARCH}/core/${FILE}" -c -O "${DIR}/${FILE}"
    xz -dc "${DIR}/$FILE" | tar x -k -C "${CHROOT_DIR}"
    rm -f "${CHROOT_DIR}/.PKGINFO" "${CHROOT_DIR}/.MTREE" "${CHROOT_DIR}/.INSTALL"
done

# Create mount points
mount -t proc proc "${CHROOT_DIR}/proc/"
mount -t sysfs sys "${CHROOT_DIR}/sys/"
mount -o bind /dev "${CHROOT_DIR}/dev/"
mkdir -p "${CHROOT_DIR}/dev/pts"
mount -t devpts pts "${CHROOT_DIR}/dev/pts/"

# Prepare pacman installation
[ -f "/etc/resolv.conf" ] && cp "/etc/resolv.conf" "${CHROOT_DIR}/etc/"

mkdir -p "${CHROOT_DIR}/etc/pacman.d/"
echo "Server = ${MIRROR}/${ARCH}/\$repo" >> "${CHROOT_DIR}/etc/pacman.d/mirrorlist"

# Setup, update, and install pacman. Clean up package cache
chroot ${CHROOT_DIR} pacman-key --init
chroot ${CHROOT_DIR} pacman-key --populate archlinux
chroot ${CHROOT_DIR} pacman -Syu --noconfirm pacman --force
chroot ${CHROOT_DIR} pacman --noconfirm -Sc

# Restore file after pacman installation
[ -f "/etc/resolv.conf" ] && cp "/etc/resolv.conf" "${CHROOT_DIR}/etc/"
