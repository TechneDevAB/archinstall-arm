archinstall-arm
===============

Script to install ArchLinux ARM RFS into a directory. Suitable for
creating an ArchLinux ARM image from scratch (about 200MB).

Script is stolen from:

  https://wiki.archlinux.org/index.php/Install_from_Existing_Linux

Must be run on an ARM platform (tested on Raspberry Pi).

Script is available under
[GNU Free Documentation License 1.3](http://www.gnu.org/copyleft/fdl.html)
or later.

Instructions
------------

Run script on ARM platform, a Raspberry Pi for instance.

        ./archinstall-bootstrap.sh

To create a Docker image from scratch, import the content in the
created directory:

        tar --numeric-owner -cf- -C archinstall-chroot . | docker import - techne/arch-rpi-base
