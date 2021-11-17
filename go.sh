#!/bin/sh

echo "Clearing steamlink.crashcounter."
fts-set steamlink.crashcounter 0

PRELOAD=
KERNEL_RELEASE=$(uname -r)
if [ "$KERNEL_RELEASE" == "3.8.13-mrvl" ]; then
  # Stock kernel needs kexec module and preload
  echo "Loading kexec kernel module."
  insmod ~/kexec/kexec-mod.ko
  PRELOAD=~/kexec/redir.so
fi

# Set command line args
CMD_LINE="console=ttyS0,115200 earlyprintk root=/dev/mtdblock5 rootfstype=yaffs2 ro root_part_name=rootfs init=/sbin/init mtdparts=mv_nand:1M(block0),8M(bootloader),11M(env),512M(sysconf),32M(factory_setting),32M(bootimgs),128M(recovery),32M(fts),384M(factory),1G(rootfs),1924M(cache),8M(bbt)"

echo "Loading new kernel into memory."
LD_PRELOAD=${PRELOAD} ~/kexec/kexec --load ~/kernel/zImage --initrd ~/kernel/initramfs.cpio.gz --dtb ~/kernel/steamlink.dtb --command-line="${CMD_LINE}"

echo "Starting new kernel."
LD_PRELOAD=${PRELOAD} ~/kexec/kexec -e
