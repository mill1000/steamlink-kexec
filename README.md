# steamlink-kexec
Adventures in booting alternate kernels using kexec on Steamlink hardware.

## Building
### Prerequisites
Recommend building on Ubuntu 16.04 LTS with gcc-4.9-arm-linux-gnueabihf. 

```
sudo apt-get install pkgconf libtool build-essential automake libncurses5-dev gcc-4.9-arm-linux-gnueabihf
```

The included toolchain as of [steamlink-sdk/8adcce1](https://github.com/ValveSoftware/steamlink-sdk/tree/8adcce1d8fb2b8c0fc4ae2aebdeeb620bc443ed1) builds a broken kernel that will panic. For some reason kzalloc was returning ZERO_SIZE_PTR for non-zero allocations due to inlining optimizations.

If building on a newer OS you may come across this [issue with libmpfr.so.4](https://github.com/ValveSoftware/steamlink-sdk/issues/31).

### Environment
Setup your environment.

```
export ARCH=arm; export LOCALVERSION="-mrvl"; export CROSS_COMPILE=arm-linux-gnueabihf-
```

### Building kexec-module
The `kexec-mod` module must be built against the stock kernel otherwise the version magic won't match and it will refuse to load. We only need to do this once so either follow the instruction below or grab the pre-compiled module from `overlay/home/steam/kexec`.

Switch to stock kernel and build modules.

```
cd steamlink-sdk
git checkout master

cd kernel
make bg2cd_penguin_mlc_defconfig
make modules -j8
```

Build kexec module.

```
cd tools/kexec-module/kernel
KDIR=`git rev-parse --show-superproject-working-tree`/steamlink-sdk/kernel make
```

Build the kexec redirector while we're at it.

```
cd tools/kexec-module/usr
make
```

Switch back to the updated kernel.

```
cd steamlink-sdk
git checkout kexec/806
```

### Building kexec-tools
We need `kexec` from `kexec-tools` to load and execute the new kernel.

```
cd tools/kexec-tools
./bootstrap
./configure --host=arm-linux-gnueabihf
make
```

### Building the kernel
Configure the kernel. This default configuration is derived from `bg2cd_penguin_mlc_defconfig`.

```
cd steamlink-sdk/kernel
make steamlink_kexec_defconfig
make -j8
```

We will need the modules as well so we'll install them to the overlay.
```
make INSTALL_MOD_PATH=`git rev-parse --show-superproject-working-tree`/overlay/ modules_install
```

## Installing
### Disclaimer
Following these steps **will** modify your Steamlink's system. While I believe a factory reset can undo all the changes I won't be held responsible if your Steamlink becomes a paper weight.

### Enable SSH access
Follow these instructions from the steamlink-sdk to [enable SSH access](https://github.com/ValveSoftware/steamlink-sdk#ssh-access). I recommend installing your SSH key as well to avoid typing a password every time.

### Copy startup scripts and misc tools
The startup scripts `S10wifi` and `S11mwifiex` load the correct WiFi drivers depending on which kernel is running. The `S05overlay` script enables an overlay filesystem on `/lib` where we can update firmware and kernel modules.

In addition, a `safe_reboot` script resets the crash counter before rebooting the system, without this the bootloader will perform a factory reset after too many "unexpected" reboots.

```
scp overlay/etc/init.d/startup/* root@<steamlink_ip>:/etc/init.d/startup
tar -zcf - -C overlay/usr/local/ . | ssh root@192.168.1.156 "tar xzf - -C /usr/local/"
scp overlay/usr/local/* root@<steamlink_ip>:/usr/local
```

Reboot the steamlink to enable the `/lib` overlay.

```
ssh root@<steamlink_ip> safe_reboot
```

### Copy kexec files
Now copy over the kexec files, either from their build locations or from the `overlay` directory of the repo.

```
ssh root@<steamlink_ip> "mkdir -p ~/kexec"
scp tools/kexec-module/kernel/kexec-mod.ko root@<steamlink_ip>:~/kexec
scp tools/kexec-module/user/redir.so root@<steamlink_ip>:~/kexec
scp tools/kexec-tools/build/sbin/kexec root@<steamlink_ip>:~/kexec
```

### Copy kernel, DTB and initramfs
Copy over new kernel and the extracted DTB and initramfs.

```
ssh root@<steamlink_ip> "mkdir -p ~/kernel"
scp extracted/latest/steamlink.dtb root@<steamlink_ip>:~/kernel
scp extracted/latest/initramfs.cpio.gz root@<steamlink_ip>:~/kernel
scp steamlink-sdk/kernel/arch/arm/boot/zImage root@<steamlink_ip>:~/kernel
```

### Copy kernel modules and firmware
Using the new `/lib` overlay we will provide new firmware and modules for the new kernel.

```
tar -zcf - -C overlay/lib/modules/ 3.8.14-mrvl | ssh root@192.168.1.156 "tar xzf - -C /lib/modules"
tar -zcf - -C overlay/lib/firmware/ mrvl | ssh root@192.168.1.156 "tar xzf - -C /lib/firmware"
```

## Booting the new kernel
Once the supporting files are installed, the new kernel can be loaded on boot by placing the `factory_test/run.sh` script on a FAT32 USB drive. The Steamlink will automatically mount and run the script, loading the new kernel shortly after startup.

```
cp factory_test/run.sh <path_to_drive>/steamlink/factory_test/run.sh
```

Plug the USB drive into the Steamlink and reboot via `safe_reboot` or power cycle.

To return to the stock kernel, simply remove the USB drive and reboot.

### Booting via the terminal
It is possible to boot the new kernel from the command line without using the factory_test script but without additional preparation it will fail.
* Disable the watchdog. Remove or rename `/etc/init.d/startup/S80watchdog` and reboot the system. If left enabled, the watchdog will reboot the device before the new kernel has a chance to fully boot.
* Disable the user interface. Remove or rename `/home/steam/rc.local`. This script loads additional modules, some tools and starts the Steamlink interface. Unfortunately its usually locks up or panics if the system was already initialized before.

The following script can be used to boot the new kernel.
```
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
```

## Organization
- extracted - Kernel, DTB, initramfs, and configs extracted from OEM firmware.
- factory_test - "Factory test" script that executes on boot to load new kernel.
- overlay - Overlay file system needed to boot new kernel and load mwifiex drivers.
- steamlink-sdk - Steamlink SDK provided by Valve including kernel sources and toolchain.
- tools - Tools necessary to perform kexec on device.

## References
- https://heap.ovh/getting-linux-on-valve-steam-link.html
- https://www.reddit.com/r/Steam_Link/comments/fgew5x/running_archlinux_on_steam_link_revisited/
- https://github.com/lukas2511/steamlink-sdk
- https://web.archive.org/web/20190925025431/http://www.livxtrm.com/steamlink/
- https://forum.doozan.com/read.php?8,46664,page=1