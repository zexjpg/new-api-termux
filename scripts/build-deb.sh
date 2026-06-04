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
export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/glibc/lib
exec /data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1 \
  "$DIR/../lib/new-api/new-api-bin" "$@"
LAUNCHER
chmod 755 "$DEB_ROOT/$PREFIX/bin/$PKG_NAME"

# Create start convenience script
cat > "$DEB_ROOT/$PREFIX/bin/new-api-start" << 'START'
#!/data/data/com.termux/files/usr/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/../lib/new-api" 2>/dev/null || cd ~
mkdir -p logs
echo "Starting New API on port 3000..."
exec new-api --port 3000 --log-dir logs "$@"
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
Depends: glibc
Description: New API - LLM gateway and AI resource management for Termux
 Unified API gateway for OpenAI, Claude, Gemini, DeepSeek and more.
Homepage: https://github.com/QuantumNous/new-api
CONTROL

# postinst hook
cat > "$DEB_ROOT/DEBIAN/postinst" << 'POSTINST'
#!/data/data/com.termux/files/usr/bin/bash
set -e
echo ""
echo " New API for Termux installed!"
echo ""
echo " Quick start:  new-api --port 3000 --log-dir ~/newapi-logs"
echo " Or use:       new-api-start"
echo " Web UI:       http://localhost:3000"
echo ""
POSTINST
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

dpkg-deb --build "$DEB_ROOT" "$OUTDIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
rm -rf "$DEB_ROOT"
echo "Package created: $OUTDIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
