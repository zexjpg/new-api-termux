#!/usr/bin/env bash
set -euo pipefail

# Usage: build-deb.sh <version> <binary-path> <output-dir>
# Builds a Termux .deb package for new-api

VERSION="${1:?Usage: build-deb.sh <version> <binary-path> <output-dir>}"
BINARY="${2:?}"
OUTDIR="${3:?}"

PREFIX="data/data/com.termux/files/usr"
DEB_ROOT="$(mktemp -d)"
PKG_NAME="new-api"
ARCH="aarch64"
MAINTAINER="zexjpg <zexjpg@users.noreply.github.com>"

mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/$PREFIX/bin"
mkdir -p "$DEB_ROOT/$PREFIX/lib/$PKG_NAME"
mkdir -p "$OUTDIR"

# Install binary
install -m 755 "$BINARY" "$DEB_ROOT/$PREFIX/lib/$PKG_NAME/new-api-bin"

# Create launcher script
cat > "$DEB_ROOT/$PREFIX/bin/$PKG_NAME" << 'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
THIS="${BASH_SOURCE[0]}"
DIR="$(cd "$(dirname "$THIS")" && pwd -P)"
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
exec proot -b /data/data/com.termux/files/usr/etc/resolv.conf:/etc/resolv.conf \
  /data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1 \
  --library-path /data/data/com.termux/files/usr/glibc/lib \
  "$DIR/../lib/new-api/new-api-bin" "$@"
LAUNCHER
chmod 755 "$DEB_ROOT/$PREFIX/bin/$PKG_NAME"

# Create start convenience script
cat > "$DEB_ROOT/$PREFIX/bin/new-api-start" << 'START'
#!/data/data/com.termux/files/usr/bin/bash
DATA_DIR="$HOME/newapi"
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"
echo "Starting New API on port 3000..."
exec new-api --port 3000 --log-dir "$DATA_DIR/logs" "$@"
START
chmod 755 "$DEB_ROOT/$PREFIX/bin/new-api-start"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)

# Control file
cat > "$DEB_ROOT/DEBIAN/control" << CONTROL
Package: $PKG_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Section: utils
Priority: optional
Installed-Size: $INSTALLED_SIZE
Depends: glibc, proot
Description: New API - LLM gateway and AI resource management for Termux
 Unified API gateway for OpenAI, Claude, Gemini, DeepSeek and more.
Homepage: https://github.com/QuantumNous/new-api
CONTROL

# postinst hook
cat > "$DEB_ROOT/DEBIAN/postinst" << 'POSTINST'
#!/data/data/com.termux/files/usr/bin/bash
set -e
# Fix glibc linker scripts (.so) that are actually GNU ld scripts,
# not valid ELF shared libraries. Replace them with symlinks to
# the actual versioned runtime libraries (.so.6).
GLIBC_LIB=/data/data/com.termux/files/usr/glibc/lib
if [ -d "$GLIBC_LIB" ]; then
  for f in "$GLIBC_LIB"/*.so; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      magic=$(head -c 4 "$f" 2>/dev/null)
      if [ "$magic" = "/* G" ]; then
        base="${f%.so}"
        for ver in 6 3 2 1 0; do
          real="${base}.so.${ver}"
          if [ -f "$real" ]; then
            mv "$f" "${f}.script"
            ln -s "$(basename "$real")" "$f"
            break
          fi
        done
      fi
    fi
  done
fi
echo ""
echo " New API for Termux installed!"
echo ""
echo " Quick start:  new-api-start"
echo "   - runs on port 3000, data/logs in ~/newapi/"
echo ""
echo " Manual start: new-api --port 3000 --log-dir ~/newapi/logs"
echo " Web UI:       http://localhost:3000"
echo ""
echo " Note: On read-only /etc filesystems, proot transparently"
echo "       resolves /etc/resolv.conf for DNS connectivity."
echo ""
POSTINST
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

dpkg-deb --build "$DEB_ROOT" "$OUTDIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
rm -rf "$DEB_ROOT"
echo "Package created: $OUTDIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
