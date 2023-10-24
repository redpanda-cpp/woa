#!/bin/bash

set -euxo pipefail

LLVM_MINGW_VERSION="20231017"
WINDOWS_TERMINAL_VERSION="1.18.2822.0"
REDPANDA_VERSION="2.25"

_QMAKE="/clangarm64/qt5-static/bin/qmake"
_MAKE="mingw32-make"
_NSIS="/mingw32/bin/makensis"

_LLVM_MINGW_DIRECTORY="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-aarch64"
_LLVM_MINGW_ARCHIVE="${_LLVM_MINGW_DIRECTORY}.zip"

_WINDOWS_TERMINAL_DIRECTORY="terminal-${WINDOWS_TERMINAL_VERSION}"
_WINDOWS_TERMINAL_ARCHIVE="Microsoft.WindowsTerminal_${WINDOWS_TERMINAL_VERSION}_arm64.zip"

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

download-windows-terminal() {
	[[ -f ${_WINDOWS_TERMINAL_ARCHIVE} ]] || curl -LO "https://github.com/microsoft/terminal/releases/download/v${WINDOWS_TERMINAL_VERSION}/${_WINDOWS_TERMINAL_ARCHIVE}"
}

prepare-openconsole() {
	[[ -f ${_WINDOWS_TERMINAL_DIRECTORY} ]] || ( download-windows-terminal && 7z x ${_WINDOWS_TERMINAL_ARCHIVE} )
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

	cp ${_WINDOWS_TERMINAL_DIRECTORY}/OpenConsole.exe ${_PKGDIR}
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
	cat >"${_PKGDIR}"/config-clang.nsh <<-EOF
		!define COMPILERNAME "Clang"
		!define COMPILERFOLDER "MinGW64"
		!define DEVCPP_VERSION "${REDPANDA_VERSION}"
		EOF

	pushd "${_PKGDIR}"
	cp "${_SRCDIR}"/platform/windows/installer-scripts/lang.nsh .
	cp ../redpanda-woa-clang.nsi .
	[[ -d MinGW64 ]] || cp -r ../${_LLVM_MINGW_DIRECTORY} MinGW64
	${_NSIS} redpanda-woa-clang.nsi
	7z-repack Clang
	popd
}

build-xross86-compiler-wrapper() {
	for prog in $( ls MinGW32/bin/i686-w64-mingw32-*.exe | awk '{ match($0, /.*i686-w64-mingw32-(.*).exe/, m) ; print m[1] }' )
	do
		MinGW32/bin/aarch64-w64-mingw32-clang++ -std=c++20 -Os -DNDEBUG -DPROG=\"${prog}\" -o MinGW32/bin/${prog}.exe ../xross86.cpp
		strip MinGW32/bin/${prog}.exe
	done
}

package-xross86() {
	cat >"${_PKGDIR}"/config-clang.nsh <<-EOF
		!define COMPILERNAME "Xross86"
		!define COMPILERFOLDER "MinGW32"
		!define DEVCPP_VERSION "${REDPANDA_VERSION}"
		EOF

	pushd "${_PKGDIR}"
	cp "${_SRCDIR}"/platform/windows/installer-scripts/lang.nsh .
	cp ../redpanda-woa-clang.nsi .
	[[ -d MinGW32 ]] || ( cp -r ../${_LLVM_MINGW_DIRECTORY} MinGW32 && build-xross86-compiler-wrapper )
	${_NSIS} redpanda-woa-clang.nsi
	7z-repack Xross86
	popd
}

dist() {
	mkdir -p "${_DISTDIR}"
	mv "${_PKGDIR}"/RedPanda.CPP.*.exe "${_PKGDIR}"/RedPanda.CPP.*.7z "${_DISTDIR}"
}

main() {
	prepare-llvm-mingw
	prepare-openconsole
	prepare-redpanda-source
	build
	package-none
	package-clang
	package-xross86
	dist
}

main
