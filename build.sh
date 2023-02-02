#!/bin/bash

set -xe

LLVM_MINGW_VERSION="20220906"
REDPANDA_VERSION="2.10"

_QMAKE="/clangarm64/qt5-static/bin/qmake"
_MAKE="mingw32-make"
_NSIS="/mingw32/bin/makensis"

_LLVM_MINGW_DIRECTORY="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-aarch64"
_LLVM_MINGW_ARCHIVE="${_LLVM_MINGW_DIRECTORY}.zip"

_REDPANDA_SOURCE_DIRECTORY="RedPanda-CPP-${REDPANDA_VERSION}"
_REDPANDA_SOURCE_ARCHIVE="${_REDPANDA_SOURCE_DIRECTORY}.zip"

_SRCDIR="$PWD/${_REDPANDA_SOURCE_DIRECTORY}"
_PKGDIR="$PWD/package"
_DISTDIR="$PWD/dist"

download-llvm-mingw() {
	[[ -f ${_LLVM_MINGW_ARCHIVE} ]] || curl -LO "https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/${_LLVM_MINGW_ARCHIVE}"
}

prepare-llvm-mingw() {
	[[ -d ${_LLVM_MINGW_DIRECTORY} ]] || ( download-llvm-mingw && 7z x ${_LLVM_MINGW_ARCHIVE} )
}

download-redpanda-source() {
	[[ -f ${_REDPANDA_SOURCE_ARCHIVE} ]] || curl -L -o ${_REDPANDA_SOURCE_ARCHIVE} "https://github.com/royqh1979/RedPanda-CPP/archive/refs/tags/${REDPANDA_VERSION}.zip"
}

prepare-redpanda-source() {
	[[ -d ${_REDPANDA_SOURCE_DIRECTORY} ]] || ( download-redpanda-source && 7z x ${_REDPANDA_SOURCE_ARCHIVE} )
}

build() {
	mkdir -p build && pushd build
	${_QMAKE} PREFIX="${_PKGDIR}" "${_SRCDIR}"
	time ${_MAKE} -j$(nproc)
	${_MAKE} install
	popd
}

generate-nsis-config() {
	cat >"${_PKGDIR}"/config-clang.nsh <<-EOF
		!define COMPILERNAME "Clang"
		!define DEVCPP_VERSION "${REDPANDA_VERSION}"
		EOF
}

7z-repack() {
	local compiler=$1
	7z x RedPanda.CPP.${REDPANDA_VERSION}.WoA.${compiler}.exe -o"RedPanda-CPP" -xr'!$PLUGINSDIR'
	7z a -t7z -m0=LZMA:d=64m:fb=273 -ms RedPanda.CPP.${REDPANDA_VERSION}.WoA.${compiler}.7z RedPanda-CPP
	rm -r RedPanda-CPP
}

package-none() {
	pushd "${_PKGDIR}"
	cp "${_SRCDIR}"/platform/windows/installer-scripts/lang.nsh .
	cp ../redpanda-woa-none.nsi .
	${_NSIS} redpanda-woa-none.nsi
	7z-repack None
	popd
}

package-clang() {
	pushd "${_PKGDIR}"
	cp "${_SRCDIR}"/platform/windows/installer-scripts/lang.nsh .
	cp ../redpanda-woa-clang.nsi .
	[[ -d MinGW64 ]] || cp -r ../${_LLVM_MINGW_DIRECTORY} MinGW64
	${_NSIS} redpanda-woa-clang.nsi
	7z-repack Clang
	popd
}

dist() {
	mkdir -p "${_DISTDIR}"
	mv "${_PKGDIR}"/*.exe "${_PKGDIR}"/*.7z "${_DISTDIR}"
}

main() {
	prepare-llvm-mingw
	prepare-redpanda-source
	build
	generate-nsis-config
	package-none
	package-clang
}

main
