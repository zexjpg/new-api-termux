#!/data/data/com.termux/files/usr/bin/bash
# Install New API for Termux from zexjpg/new-api-termux

REPO="zexjpg/new-api-termux"
VERSION="${1:-latest}"
TMP="${TMPDIR:-$PREFIX/tmp}"
MIRROR="https://gh-proxy.com"

G='\033[1;32m'; R='\033[1;31m'; N='\033[0m'
log() { printf "${G}[install]${N} %s\n" "$*"; }
die() { printf "${R}[install]${N} %s\n" "$*" >&2; exit 1; }

command -v dpkg >/dev/null 2>&1 || die "dpkg required (are you on Termux?)"
command -v curl >/dev/null 2>&1 || die "curl required (apt install curl)"
command -v uname >/dev/null 2>&1 || die "uname required"

ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] || die "Only aarch64 is supported, current: $ARCH"

if [ "$VERSION" = "latest" ]; then
  log "Detecting latest version..."
  VERSION=$(curl -sL --connect-timeout 5 -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest" 2>/dev/null | grep -o 'tag/v[^"]*' | sed 's/^tag\/v//')
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -sL --connect-timeout 10 \
      "$MIRROR/https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
  fi
  [ -n "$VERSION" ] || die "Failed. Specify version: install.sh 1.0.0-rc.10"
  log "Latest: $VERSION"
fi

log "Installing dependencies..."
apt install -y glibc-repo >/dev/null 2>&1
apt update >/dev/null 2>&1 || true
apt install -y glibc >/dev/null 2>&1 || true

DEB="new-api_${VERSION}_aarch64.deb"
URL="https://github.com/$REPO/releases/download/v$VERSION/$DEB"
MURL="$MIRROR/$URL"

log "Downloading $DEB (via mirror)..."
curl -fL -o "$TMP/$DEB" "$MURL" --connect-timeout 15 --speed-time 30 --speed-limit 1024 || {
  log "Mirror slow, trying direct..."
  curl -fL -o "$TMP/$DEB" "$URL" --connect-timeout 10 --retry 2 || die "Download failed."
}

log "Installing..."
dpkg -i "$TMP/$DEB" || { apt install -f -y && dpkg -i "$TMP/$DEB"; }
rm -f "$TMP/$DEB"

log "Done! Run: new-api --help"
echo ""
echo "  Quick start:  new-api-start"
echo "    - runs on port 3000, data/logs in ~/newapi/"
echo ""
echo "  Manual:       new-api --port 3000 --log-dir ~/newapi/logs"
echo "  Web UI:       http://localhost:3000"
echo ""
