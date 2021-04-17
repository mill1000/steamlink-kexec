# steamlink-kexec
Adventures in booting alternate kernels using kexec on Steamlink hardware.

## Prerequisities
Recommend building on Ubuntu 16.04 LTS with gcc-4.9-arm-linux-gnueabihf. 

```
sudo apt-get install pkgconf libtool build-essential automake libncurses5-dev gcc-4.9-arm-linux-gnueabihf
```

The included toolchain as of [steamlink-sdk/8adcce1](https://github.com/ValveSoftware/steamlink-sdk/tree/8adcce1d8fb2b8c0fc4ae2aebdeeb620bc443ed1) builds a broken kernel that will panic. For some reason kzalloc was returning ZERO_SIZE_PTR for non-zero allocations due to inlining optimizations.

If building on a newer OS you may come accross this [issue with libmpfr.so.4.](https://github.com/ValveSoftware/steamlink-sdk/issues/31)

## Building
Setup your enviroment.
```
export ARCH=arm; export LOCALVERSION="-mrvl"; export CROSS_COMPILE=arm-linux-gnueabihf-
```

Configure the kernel. This default is derived from `bg2cd_penguin_mlc_defconfig`.
```
make steamlink_kexec_defconfig
```

Build.
```
make -j8
```

## Organization
- extracted - Kernel, DTB, initramfs, and configs extracted from OEM firmware.
- factory_test - "Factory test" script that executes on boot to load new kernel.
- overlay - Overlay file system needed to boot new kernel and load mwifiex drivers.
- steamlink-sdk - Steamlink SDK provided by Valve including kernel sources and toolchain.
- tools - Tools necessary to perform kexec on device.