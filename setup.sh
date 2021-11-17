#!/bin/sh

ssh root@192.168.1.156 << HERE
  mkdir -p ~/kernel
  mkdir -p ~/kexec
HERE

scp extracted/latest/steamlink.dtb root@192.168.1.156:~/kernel
scp extracted/latest/initramfs.cpio.gz root@192.168.1.156:~/kernel
scp steamlink-sdk/kernel/arch/arm/boot/zImage root@192.168.1.156:~/kernel

scp tools/kexec-module/kernel/kexec-mod.ko root@192.168.1.156:~/kexec
scp tools/kexec-module/user/redir.so root@192.168.1.156:~/kexec
scp tools/kexec-tools/build/sbin/kexec root@192.168.1.156:~/kexec

tar -zcf - overlay/ | ssh root@192.168.1.156 "tar xzf - -C /mnt/config/overlay/"
