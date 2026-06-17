#!/usr/bin/env bash
# =============================================================================
# Telita Linux Build & Package Script
# Generates: AppImage, .deb, and Flatpak
# Usage: bash build_linux.sh [--skip-build]
# =============================================================================

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
APP_NAME="Telita"
APP_ID="com.telita.app"
APP_VERSION="1.0.0"
ARCH="x86_64"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/core"
FLUTTER_DIR="$SCRIPT_DIR/telita_flutter"
BUNDLE_DIR="$FLUTTER_DIR/build/linux/x64/release/bundle"
ICON_SRC="$FLUTTER_DIR/assets/icon.png"
DESKTOP_SRC="$FLUTTER_DIR/linux/telita.desktop"
OUT_DIR="$SCRIPT_DIR/dist"

SKIP_BUILD=false
for arg in "$@"; do
  [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true
done

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
warn()  { echo -e "${YELLOW}⚠ $1${RESET}"; }
die()   { echo -e "${RED}✘ $1${RESET}"; exit 1; }

# ─── Dependency Checks ───────────────────────────────────────────────────────
step "Checking dependencies..."

need() {
  command -v "$1" &>/dev/null || die "'$1' not found. Install it first: $2"
}

need flutter  "https://flutter.dev"
need go       "sudo apt install golang"
need dpkg-deb "sudo apt install dpkg"
need convert  "sudo apt install imagemagick"  # for .ico / resizing if needed

# Optional — warn but don't die for Flatpak
HAVE_FLATPAK=true
HAVE_APPIMAGE=true

command -v appimagetool &>/dev/null || {
  warn "appimagetool not found — AppImage will be skipped."
  warn "Download from: https://github.com/AppImage/AppImageKit/releases"
  HAVE_APPIMAGE=false
}

command -v flatpak-builder &>/dev/null || {
  warn "flatpak-builder not found — Flatpak will be skipped."
  warn "Install with: sudo apt install flatpak-builder"
  HAVE_FLATPAK=false
}

# If flatpak-builder is available, ensure Flathub remote and runtime are present
if [[ "$HAVE_FLATPAK" == true ]]; then
  step "Ensuring Flatpak Flathub remote and runtime are available..."
  # Add Flathub remote (for current user, no sudo needed)
  flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  # Also add system-wide if we have permission (best-effort)
  sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  # Install the freedesktop runtime if not already present
  RUNTIME_VERSION="23.08"
  if ! flatpak info org.freedesktop.Platform//${RUNTIME_VERSION} &>/dev/null && \
     ! flatpak info --user org.freedesktop.Platform//${RUNTIME_VERSION} &>/dev/null; then
    step "Installing Flatpak runtime org.freedesktop.Platform//${RUNTIME_VERSION} (this may take a while)..."
    flatpak install --user -y flathub \
      org.freedesktop.Platform//${RUNTIME_VERSION} \
      org.freedesktop.Sdk//${RUNTIME_VERSION} || {
        warn "Could not install Flatpak runtime — Flatpak packaging will be skipped."
        warn "Try manually: flatpak install flathub org.freedesktop.Platform//${RUNTIME_VERSION}"
        HAVE_FLATPAK=false
      }
  else
    ok "Flatpak runtime already installed"
  fi
fi

mkdir -p "$OUT_DIR"

# ─── Step 1: Build Go Core ───────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
  step "Building Go core (libcore)..."
  cd "$CORE_DIR"
  go build -ldflags="-s -w" -o libcore .
  ok "libcore built at $CORE_DIR/libcore"
fi

# ─── Step 2: Build Flutter App ───────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
  step "Building Flutter app (release)..."
  cd "$FLUTTER_DIR"
  flutter clean
  flutter pub get
  flutter build linux --release
  ok "Flutter build complete"
fi

# ─── Step 3: Copy libcore into bundle ────────────────────────────────────────
step "Copying libcore into bundle..."
[[ -f "$BUNDLE_DIR/Telita" || -f "$BUNDLE_DIR/telita_flutter" ]] || \
  die "Flutter bundle not found at $BUNDLE_DIR. Run without --skip-build."

cp "$CORE_DIR/libcore" "$BUNDLE_DIR/libcore"
chmod +x "$BUNDLE_DIR/libcore"
ok "libcore copied to bundle"

# ─── Step 4: Register icon system-wide ───────────────────────────────────────
step "Registering icon and .desktop file system-wide..."

ICON_SIZES=(16 32 48 64 128 256 512)
for SIZE in "${ICON_SIZES[@]}"; do
  ICON_DIR="/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
  sudo mkdir -p "$ICON_DIR"
  sudo convert "$ICON_SRC" -resize "${SIZE}x${SIZE}" "$ICON_DIR/telita.png" 2>/dev/null || \
    sudo cp "$ICON_SRC" "$ICON_DIR/telita.png"
done

sudo cp "$ICON_SRC" /usr/share/icons/hicolor/256x256/apps/telita.png
sudo cp "$DESKTOP_SRC" /usr/share/applications/telita.desktop
sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database ~/.local/share/applications 2>/dev/null || true
ok "Icon and .desktop registered"

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE: AppImage
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$HAVE_APPIMAGE" == true ]]; then
  step "Building AppImage..."
  APPDIR="$OUT_DIR/Telita.AppDir"
  rm -rf "$APPDIR"

  # AppDir structure
  mkdir -p "$APPDIR/usr/bin"
  mkdir -p "$APPDIR/usr/lib"
  mkdir -p "$APPDIR/usr/share/applications"
  mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

  # Copy entire bundle
  cp -r "$BUNDLE_DIR"/. "$APPDIR/usr/bin/"

  # Icon
  cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/telita.png"
  cp "$ICON_SRC" "$APPDIR/telita.png"

  # .desktop
  cp "$DESKTOP_SRC" "$APPDIR/usr/share/applications/telita.desktop"
  # AppImage needs .desktop at root too
  cat > "$APPDIR/Telita.desktop" <<EOF
[Desktop Entry]
Name=Telita
Comment=Stream movies and TV shows
Exec=Telita
Icon=telita
Type=Application
Categories=AudioVideo;Video;Player;
EOF

  # AppRun entry point
  cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$LD_LIBRARY_PATH"
cd "$HERE/usr/bin"
# Start the Go backend in the background
if [ -f "./libcore" ]; then
  ./libcore &
  CORE_PID=$!
  trap "kill $CORE_PID 2>/dev/null" EXIT
fi
exec "$HERE/usr/bin/Telita" "$@"
EOF
  chmod +x "$APPDIR/AppRun"

  # Build AppImage
  APPIMAGE_OUT="$OUT_DIR/Telita-${APP_VERSION}-${ARCH}.AppImage"
  appimagetool "$APPDIR" "$APPIMAGE_OUT"
  chmod +x "$APPIMAGE_OUT"
  ok "AppImage created: $APPIMAGE_OUT"
else
  warn "Skipping AppImage (appimagetool not found)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE: .deb
# ─────────────────────────────────────────────────────────────────────────────
step "Building .deb package..."

DEB_DIR="$OUT_DIR/telita-deb"
INSTALL_PREFIX="$DEB_DIR/opt/telita"
rm -rf "$DEB_DIR"

mkdir -p "$INSTALL_PREFIX"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_DIR/usr/local/bin"
mkdir -p "$DEB_DIR/DEBIAN"

# Copy bundle
cp -r "$BUNDLE_DIR"/. "$INSTALL_PREFIX/"

# Icon and .desktop
cp "$ICON_SRC" "$DEB_DIR/usr/share/icons/hicolor/256x256/apps/telita.png"
cat > "$DEB_DIR/usr/share/applications/telita.desktop" <<EOF
[Desktop Entry]
Name=Telita
Comment=Stream movies and TV shows
Exec=/opt/telita/Telita
Icon=telita
Type=Application
Categories=AudioVideo;Video;Player;
Keywords=video;player;media;stream;torrent;
StartupWMClass=Telita
EOF

# Wrapper script in /usr/local/bin
cat > "$DEB_DIR/usr/local/bin/telita" <<'EOF'
#!/bin/bash
cd /opt/telita
if [ -f "./libcore" ]; then
  ./libcore &
  CORE_PID=$!
  trap "kill $CORE_PID 2>/dev/null" EXIT
fi
exec /opt/telita/Telita "$@"
EOF
chmod +x "$DEB_DIR/usr/local/bin/telita"

# postinst to update icon cache
cat > "$DEB_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
EOF
chmod 755 "$DEB_DIR/DEBIAN/postinst"

# Installed size (in KB)
INSTALLED_SIZE=$(du -sk "$INSTALL_PREFIX" | cut -f1)

# Control file
cat > "$DEB_DIR/DEBIAN/control" <<EOF
Package: telita
Version: ${APP_VERSION}
Section: video
Priority: optional
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Maintainer: Telita Team <telita@example.com>
Homepage: https://github.com/TheVolecitor/Telita
Description: Telita Media Player
 Stream movies and TV shows via torrent and direct links.
 Supports 4K, subtitles, and multiple audio tracks.
EOF

DEB_OUT="$OUT_DIR/telita_${APP_VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$DEB_DIR" "$DEB_OUT"
ok ".deb created: $DEB_OUT"

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE: Flatpak
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$HAVE_FLATPAK" == true ]]; then
  step "Building Flatpak..."
  FLATPAK_DIR="$OUT_DIR/flatpak-build"
  FLATPAK_REPO="$OUT_DIR/flatpak-repo"
  FLATPAK_BUNDLE="$OUT_DIR/Telita-${APP_VERSION}.flatpak"
  rm -rf "$FLATPAK_DIR"
  mkdir -p "$FLATPAK_DIR"

  # Force resize icon to exactly 256x256 to match the Flatpak directory and enforce a perfect square
  FLATPAK_ICON="$OUT_DIR/telita-256.png"
  convert "$ICON_SRC" -resize 256x256\! "$FLATPAK_ICON"
  ok "Icon forced to perfectly square 256x256 for Flatpak"

  # Generate a Flatpak-specific .desktop file with Icon matching the app ID
  FLATPAK_DESKTOP="$OUT_DIR/com.telita.app.desktop"
  cat > "$FLATPAK_DESKTOP" << 'DESKTOP_EOF'
[Desktop Entry]
Name=Telita
Comment=Stream movies and TV shows
Exec=telita
Icon=com.telita.app
Type=Application
Categories=AudioVideo;Video;Player;
Keywords=video;player;media;stream;torrent;
StartupWMClass=Telita
DESKTOP_EOF

  # Write the launcher wrapper as a real file to avoid JSON escaping issues
  LAUNCHER="$OUT_DIR/telita-launcher.sh"
  cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
cd /app/bin
if [ -f "./libcore" ]; then
  ./libcore &
  CORE_PID=$!
  trap "kill $CORE_PID 2>/dev/null" EXIT
fi
exec /app/bin/Telita "$@"
LAUNCHER_EOF
  chmod +x "$LAUNCHER"

  # Write Flatpak manifest — reference launcher as a source file
  MANIFEST="$OUT_DIR/${APP_ID}.json"
  cat > "$MANIFEST" << EOF
{
  "app-id": "${APP_ID}",
  "runtime": "org.freedesktop.Platform",
  "runtime-version": "23.08",
  "sdk": "org.freedesktop.Sdk",
  "command": "telita",
  "finish-args": [
    "--share=ipc",
    "--share=network",
    "--socket=x11",
    "--socket=wayland",
    "--socket=pulseaudio",
    "--device=dri",
    "--filesystem=home",
    "--talk-name=org.freedesktop.ScreenSaver"
  ],
  "modules": [
    {
      "name": "telita",
      "buildsystem": "simple",
      "build-commands": [
        "install -Dm755 Telita /app/bin/Telita",
        "install -Dm755 libcore /app/bin/libcore",
        "cp -r lib /app/bin/lib",
        "cp -r data /app/bin/data",
        "install -Dm644 telita.png /app/share/icons/hicolor/256x256/apps/${APP_ID}.png",
        "install -Dm644 telita.desktop /app/share/applications/${APP_ID}.desktop",
        "install -Dm755 telita-launcher.sh /app/bin/telita"
      ],
      "sources": [
        {
          "type": "dir",
          "path": "${BUNDLE_DIR}"
        },
        {
          "type": "file",
          "path": "${FLATPAK_ICON}",
          "dest-filename": "telita.png"
        },
        {
          "type": "file",
          "path": "${FLATPAK_DESKTOP}",
          "dest-filename": "telita.desktop"
        },
        {
          "type": "file",
          "path": "${LAUNCHER}",
          "dest-filename": "telita-launcher.sh"
        }
      ]
    }
  ],
  "cleanup": ["*.a", "*.la"]
}
EOF

  # eu-strip (from elfutils) is required by this version of flatpak-builder
  if ! command -v eu-strip &>/dev/null; then
    step "Installing elfutils (required by flatpak-builder for stripping)..."
    sudo apt install -y elfutils || warn "Could not install elfutils — Flatpak may fail"
  fi

  flatpak-builder --force-clean \
    --repo="$FLATPAK_REPO" "$FLATPAK_DIR" "$MANIFEST"
  flatpak build-bundle "$FLATPAK_REPO" "$FLATPAK_BUNDLE" "${APP_ID}"
  ok "Flatpak created: $FLATPAK_BUNDLE"

  echo ""
  echo -e "${CYAN}To install the Flatpak locally:${RESET}"
  echo "  flatpak install --user $FLATPAK_BUNDLE"
else
  warn "Skipping Flatpak (flatpak-builder not found)"
  echo "  Install with: sudo apt install flatpak-builder"
  echo "  Then add the runtime: flatpak install flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Telita packaging complete!${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${RESET}"
echo ""
echo -e "Output files in: ${CYAN}$OUT_DIR${RESET}"
ls -lh "$OUT_DIR"/*.AppImage "$OUT_DIR"/*.deb "$OUT_DIR"/*.flatpak 2>/dev/null || true
echo ""
echo -e "${YELLOW}Quick install tips:${RESET}"
echo "  AppImage:  chmod +x Telita-*.AppImage && ./Telita-*.AppImage"
echo "  .deb:      sudo dpkg -i telita_*.deb"
echo "  Flatpak:   flatpak install --user Telita-*.flatpak"