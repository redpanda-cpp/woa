# [Red Panda C++](https://github.com/royqh1979/RedPanda-CPP) for Windows on ARM

## Build

Environment: MSYS2 CLANGARM64.

Required packages:
* `mingw-w64-clang-aarch64-toolchain`
* `mingw-w64-clang-aarch64-qt5-static`
* `mingw-w64-clang-aarch64-7zip`
* `mingw-w64-i686-nsis`

To install required packages, run:

```bash
pacman -S mingw-w64-clang-aarch64-{toolchain,qt5-static,7zip} mingw-w64-i686-nsis
```

To build, run:

```bash
./build.sh
```
