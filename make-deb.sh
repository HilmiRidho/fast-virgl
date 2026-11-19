#!/bin/bash
# Bungkus hasil build virglrenderer menjadi .deb Termux (aarch64).
# Pakai: ./make-deb.sh <STAGE_DIR> [VERSION]
#   STAGE_DIR = folder berisi bin/ lib/ libexec/ [include/]  (mis. hasil DESTDIR install,
#               yaitu .../data/data/com.termux/files/usr/opt/virglrenderer-android)
set -e
STAGE=${1:?STAGE_DIR (berisi bin lib libexec)}
VER=${2:-1.3.0-2}
PKG=virglrenderer-android
ARCH=aarch64
TP=/data/data/com.termux/files/usr
OPT=$TP/opt/$PKG
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

for f in bin/virgl_test_server libexec/virgl_render_server; do
  [ -f "$STAGE/$f" ] || { echo "tidak ada $STAGE/$f"; exit 1; }
done
ls "$STAGE"/lib/libvirglrenderer.so* >/dev/null 2>&1 || { echo "tidak ada libvirglrenderer di $STAGE/lib"; exit 1; }
file "$STAGE/bin/virgl_test_server" | grep -q aarch64 || { echo "binary bukan aarch64"; exit 1; }

mkdir -p "$ROOT$OPT" "$ROOT$TP/bin" "$ROOT/DEBIAN"
for d in bin lib libexec include; do [ -e "$STAGE/$d" ] && cp -a "$STAGE/$d" "$ROOT$OPT/"; done
[ -f "$ROOT$OPT/lib/libepoxy.so.0.0.0" ] && {
  ( cd "$ROOT$OPT/lib" && rm -f libepoxy.so libepoxy.so.0 && ln -s libepoxy.so.0.0.0 libepoxy.so.0 && ln -s libepoxy.so.0 libepoxy.so )
}
sed -i "s|^prefix=.*|prefix=$OPT|" "$ROOT$OPT"/lib/pkgconfig/*.pc 2>/dev/null || true

DEPENDS=""
[ -f "$ROOT$OPT/lib/libepoxy.so.0.0.0" ] || DEPENDS="Depends: libepoxy"

# library asli (tanpa patch biner) untuk debugging: VIRGL_GL_ERROR_CHECK=1
ORIGLIB=$(cd "$ROOT$OPT/lib" 2>/dev/null && ls libvirglrenderer.so.1.*.orig 2>/dev/null | head -1)
if [ -n "$ORIGLIB" ]; then
  mkdir -p "$ROOT$OPT/lib-checked"
  ln -s "../lib/$ORIGLIB" "$ROOT$OPT/lib-checked/libvirglrenderer.so.1"
fi

cat > "$ROOT$TP/bin/virgl_test_server_android" <<WEOF
#!$TP/bin/sh
# Wrapper virglrenderer (Android/bionic) untuk Termux
P=$OPT
LP="\$P/lib"
# VIRGL_GL_ERROR_CHECK=1 -> pakai libvirglrenderer asli (glGetError per command aktif)
if [ "\${VIRGL_GL_ERROR_CHECK:-0}" != 0 ] && [ -d "\$P/lib-checked" ]; then
  LP="\$P/lib-checked:\$LP"
fi
export LD_LIBRARY_PATH="\$LP\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export RENDER_SERVER_EXEC_PATH="\${RENDER_SERVER_EXEC_PATH:-\$P/libexec/virgl_render_server}"
# Termux tidak punya /tmp; socket default binary (/tmp/.virgl_test) diganti
T="\${TMPDIR:-$TP/tmp}"
mkdir -p "\$T"
# prioritas lebih tinggi (best effort; VTEST_NICE=0 untuk mematikan)
N="\${VTEST_NICE:--8}"
NICE=""
if [ "\$N" != 0 ] && [ -z "\$(nice -n "\$N" true 2>&1)" ]; then NICE="nice -n \$N"; fi
for a in "\$@"; do
  case "\$a" in --socket-path*) exec \$NICE "\$P/bin/virgl_test_server" "\$@";; esac
done
rm -f "\$T/.virgl_test"
exec \$NICE "\$P/bin/virgl_test_server" --socket-path "\$T/.virgl_test" "\$@"
WEOF
chmod 755 "$ROOT$TP/bin/virgl_test_server_android"

SIZE=$(du -sk "$ROOT/data" | cut -f1)
{
cat <<CEOF
Package: $PKG
Version: $VER
Architecture: $ARCH
Maintainer: @termux
Installed-Size: $SIZE
Section: x11
Priority: optional
CEOF
[ -n "$DEPENDS" ] && echo "$DEPENDS"
cat <<CEOF
Homepage: https://gitlab.freedesktop.org/virgl/virglrenderer
Description: VirGL renderer (Android/bionic build)
 virgl_test_server and libvirglrenderer for Termux, installed under
 $OPT. Run: virgl_test_server_android
 Env: VIRGL_GL_ERROR_CHECK=1 (debug), VTEST_NICE.
CEOF
} > "$ROOT/DEBIAN/control"

OUT=$PWD/${PKG}_${VER}_${ARCH}.deb
dpkg-deb -Zxz --root-owner-group -b "$ROOT" "$OUT"
echo "OK: $OUT"
