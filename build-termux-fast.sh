#!/bin/bash
# Build virglrenderer (patched) untuk Termux aarch64 dengan NDK.
# Pakai: NDK=/path/android-ndk-r28c EPOXY_PREFIX=/path/ke/hasil-ekstrak-tar ./build-termux-fast.sh /path/virglrenderer-main
# EPOXY_PREFIX = folder berisi lib/pkgconfig/epoxy.pc (hasil ekstrak android-aarch64-api30-virglrenderer.tar.gz)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${1:?path source virglrenderer-main}
: "${NDK:?set NDK=/path/android-ndk-r28c}"
: "${EPOXY_PREFIX:?set EPOXY_PREFIX=/path/ekstrak/tar}"
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
TP=/data/data/com.termux/files/usr/opt/virglrenderer-android
cd "$SRC"
for p in "$HERE"/000*.patch; do
  [ -f "$p" ] || continue
  if patch -p1 -N --dry-run < "$p" >/dev/null 2>&1; then patch -p1 -N < "$p"; else echo "(lewati $p: sudah diterapkan / tidak cocok)"; fi
done
sed "s|^prefix=.*|prefix=$EPOXY_PREFIX|" "$EPOXY_PREFIX/lib/pkgconfig/epoxy.pc" > /tmp/epoxy.pc.fixed
mkdir -p /tmp/pc && cp /tmp/epoxy.pc.fixed /tmp/pc/epoxy.pc

cat > /tmp/android-aarch64.txt <<CF
[binaries]
c = '$TC/aarch64-linux-android30-clang'
cpp = '$TC/aarch64-linux-android30-clang++'
ar = '$TC/llvm-ar'
strip = '$TC/llvm-strip'
ranlib = '$TC/llvm-ranlib'
pkg-config = '/usr/bin/pkg-config'
[built-in options]
pkg_config_path = ['/tmp/pc']
c_args = ['-O3', '-fno-plt', '-fomit-frame-pointer']
c_link_args = ['-Wl,-O2', '-Wl,--gc-sections', '-Wl,-rpath,$TP/lib']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
CF

rm -rf build-fast
PKG_CONFIG_LIBDIR=/tmp/pc PKG_CONFIG_PATH=/tmp/pc meson setup build-fast \
  --cross-file /tmp/android-aarch64.txt \
  --prefix "$TP" --libdir lib \
  -Dbuildtype=release -Db_lto=true -Db_ndebug=true \
  -Dplatforms=egl -Dvenus=true -Dcheck-gl-errors=false -Dtests=false
ninja -C build-fast
DESTDIR=$PWD/out ninja -C build-fast install
"$TC/llvm-strip" --strip-unneeded out$TP/lib/libvirglrenderer.so.1.* out$TP/bin/virgl_test_server out$TP/libexec/virgl_render_server 2>/dev/null || true
echo "Hasil: $PWD/out$TP"
