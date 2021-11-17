#!/bin/sh

echo "Clearing steamlink.crashcounter."
fts-set steamlink.crashcounter 0

echo "Loading kexec kernel module."
insmod ~/kexec/kexec-mod.ko

echo "Loading new kernel into memory."
LD_PRELOAD=~/kexec/redir.so ~/kexec/kexec --load ~/kernel/zImage --initrd ~/kernel/initramfs.cpio.gz --dtb ~/kernel/steamlink.dtb --debug --command-line="console=ttyS0,115200 earlyprintk root=/dev/mtdblock5 rootfstype=yaffs2 ro root_part_name=rootfs init=/sbin/init mtdparts=mv_nand:1M(block0),8M(bootloader),11M(env),512M(sysconf),32M(factory_setting),32M(bootimgs),128M(recovery),32M(fts),384M(factory),1G(rootfs),1924M(cache),8M(bbt)"

echo "Cleaning up Bluetooth"
if pgrep -x "bluetoothd" > /dev/null; then
bluetoothctl <<EOF
power off
exit
EOF
fi
rmmod bt8xxx

echo "Cleaning up WiFi"
ifconfig mlan0 down
rmmod sd8897
rmmod 8897mlan

# Force a WiFi reset
#/bin/wifi_reset

echo "Starting new kernel..."
LD_PRELOAD=~/kexec/redir.so ~/kexec/kexec -e

