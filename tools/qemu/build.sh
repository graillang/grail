#!/bin/sh
# Build the aarch64 user-mode emulator the cross legs run under: QEMU 11.1.3 with stlr-rcsc.patch
# (a store-release is followed by a full barrier, so STLR; LDAR cannot pass each other on an x86
# host, which ARMv8 forbids and stock 11.1.3 allows; tests/atomics/litmus_sb.grl showed it). It is
# installed where tools/native.mjs `runner()` looks first after GRAIL_QEMU_AARCH64:
# .work/architectures/toolchain/usr/bin/qemu-aarch64-static. `--version` ends in
# `(grail-stlr-rcsc)`, which is how tools/test-atomics-litmus.mjs knows store buffering may be
# asserted under it. Static, so it needs a static zlib, built here as well; nothing needs root.
#   tools/qemu/build.sh            build unless the installed binary is already this one
#   tools/qemu/build.sh --force    rebuild
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
here=$root/tools/qemu
out=$root/.work/architectures/toolchain/usr/bin/qemu-aarch64-static
work=$root/.work/qemu-build
QEMU=qemu-11.1.3
QEMU_SHA256=5a8289c7940dc77d3873c81a6c29ba3afe1446fc9d36e77fa1658cdbecb84b22
ZLIB=zlib-1.3.1
ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23

if [ "${1:-}" != --force ] && [ -x "$out" ] && "$out" --version | grep -q '(grail-stlr-rcsc)'; then
  "$out" --version | head -1
  exit 0
fi
mkdir -p "$work" "$(dirname "$out")"
cd "$work"
fetch() {
  if [ ! -f "$2" ]; then
    curl -sSfL -o "$2.part" "$1"
    mv "$2.part" "$2"
  fi
  if ! echo "$3  $2" | sha256sum -c --quiet -; then
    echo "build.sh: $2 does not have the expected sha256 $3" >&2
    rm -f "$2"
    exit 1
  fi
}
fetch "https://download.qemu.org/$QEMU.tar.xz" "$QEMU.tar.xz" "$QEMU_SHA256"
fetch "https://github.com/madler/zlib/releases/download/v1.3.1/$ZLIB.tar.gz" "$ZLIB.tar.gz" "$ZLIB_SHA256"
jobs=$(nproc 2>/dev/null || echo 4)

rm -rf "$ZLIB" deps
tar xzf "$ZLIB.tar.gz"
(cd "$ZLIB" && ./configure --static --prefix="$work/deps" > /dev/null && make -j"$jobs" > /dev/null && make install > /dev/null)

rm -rf "$QEMU"
tar xJf "$QEMU.tar.xz"
(cd "$QEMU" && patch -p1 --quiet < "$here/stlr-rcsc.patch")
mkdir "$QEMU/build"
cd "$QEMU/build"
PKG_CONFIG_PATH="$work/deps/lib/pkgconfig" ../configure --target-list=aarch64-linux-user --static \
  --disable-docs --disable-tools --disable-werror --disable-plugins --with-pkgversion=grail-stlr-rcsc \
  --extra-ldflags="-L$work/deps/lib" --extra-cflags="-I$work/deps/include" > "$work/configure.log" 2>&1 \
  || { echo "build.sh: configure failed, see $work/configure.log" >&2; exit 1; }
ninja -j"$jobs" qemu-aarch64 > "$work/build.log" 2>&1 \
  || { echo "build.sh: build failed, see $work/build.log" >&2; exit 1; }
strip -o "$out.part" qemu-aarch64
mv "$out.part" "$out"
"$out" --version | head -1
