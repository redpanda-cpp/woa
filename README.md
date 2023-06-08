**English** [简体中文](README-CN.md)

# [Red Panda C++](https://github.com/royqh1979/RedPanda-CPP) for Windows on Arm

## Distribution Packages

### Compiler Type

* `None`: Red Panda C++ (Arm64) without compiler.
* `Clang`: Red Panda C++ (Arm64) with Clang (Arm64 native).
* `Xross86`: Red Panda C++ (Arm64) with Clang (cross-compiler for x86 on Arm64).
  - Useful if you want to share your program with friends.
  - Clang itself is an Arm64 app, while it generates x86 binaries by default.
  - Debugger is not available.

### Installation Option

* `.exe`: standard setup.
* `.7z`: portable application.

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
