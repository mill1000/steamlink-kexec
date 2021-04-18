# steamlink-kexec
Adventures in booting alternate kernels using kexec on Steamlink hardware.

## Prerequisites
Recommend building on Ubuntu 16.04 LTS with gcc-4.9-arm-linux-gnueabihf. 

```
sudo apt-get install pkgconf libtool build-essential automake libncurses5-dev gcc-4.9-arm-linux-gnueabihf
```

The included toolchain as of [steamlink-sdk/8adcce1](https://github.com/ValveSoftware/steamlink-sdk/tree/8adcce1d8fb2b8c0fc4ae2aebdeeb620bc443ed1) builds a broken kernel that will panic. For some reason kzalloc was returning ZERO_SIZE_PTR for non-zero allocations due to inlining optimizations.

If building on a newer OS you may come across this [issue with libmpfr.so.4.](https://github.com/ValveSoftware/steamlink-sdk/issues/31)

## Building
Setup your environment.
```
export ARCH=arm; export LOCALVERSION="-mrvl"; export CROSS_COMPILE=arm-linux-gnueabihf-
```

### Building kexec-module
The kexec module must be built against the stock kernel otherwise the version magic won't match and it will refuse to load. We only need to do this once so either follow the instruction below or grab the pre-compiled module from `overlay/home/steam/kexec`.

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

## Organization
- extracted - Kernel, DTB, initramfs, and configs extracted from OEM firmware.
- factory_test - "Factory test" script that executes on boot to load new kernel.
- overlay - Overlay file system needed to boot new kernel and load mwifiex drivers.
- steamlink-sdk - Steamlink SDK provided by Valve including kernel sources and toolchain.
- tools - Tools necessary to perform kexec on device.