#!/usr/bin/env bash
# Build Hypercluster.app, bundle CLI runtime, and produce Hypercluster-<version>.pkg with Zyvor EULA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=arch-check.sh
source "${ROOT}/scripts/macos/arch-check.sh"
VERSION="$(cat "${ROOT}/VERSION" 2>/dev/null || echo 0.1.0)"
DIST="${ROOT}/desktop/distribution"
STAGE="${ROOT}/desktop/distribution/pkg-stage"
PKG_OUT="${DIST}/Hypercluster-${VERSION}-arm64.pkg"
TAURI_TARGET="$(hc_macos_tauri_release_target)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS pkg build requires Darwin." >&2
  exit 1
fi

hc_macos_require_arm64_host

echo "→ Building Hypercluster Desktop (Tauri, ${TAURI_TARGET})…"
APP=""
for candidate in \
  "${ROOT}/desktop/src-tauri/target/${TAURI_TARGET}/release/bundle/macos/Hypercluster.app" \
  "${ROOT}/desktop/src-tauri/target/release/bundle/macos/Hypercluster.app"; do
  if [[ -d "$candidate" && -w "$candidate" ]]; then
    APP="$candidate"
    echo "  Using existing Hypercluster.app (skip tauri build): $APP"
    break
  fi
done
if [[ -z "$APP" ]]; then
  (cd "${ROOT}/desktop" && npm install && npm run tauri build -- --bundles app --target "$TAURI_TARGET")
fi

APP="$(find "${ROOT}/desktop/src-tauri/target/${TAURI_TARGET}/release/bundle/macos" -name 'Hypercluster.app' -type d 2>/dev/null | head -1 || true)"
if [[ -z "$APP" ]]; then
  APP="$(find "${ROOT}/desktop/src-tauri/target/release/bundle/macos" -name 'Hypercluster.app' -type d 2>/dev/null | head -1 || true)"
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "ERROR: Hypercluster.app not found after tauri build." >&2
  exit 1
fi
echo "  App: $APP"
hc_macos_require_arm64_app "$APP"

RUNTIME="${APP}/Contents/Resources/hypercluster-runtime"
mkdir -p "${RUNTIME}/lib" "${RUNTIME}/config"
cp "${ROOT}/hypercluster" "${RUNTIME}/"
chmod +x "${RUNTIME}/hypercluster"
cp -R "${ROOT}/lib/." "${RUNTIME}/lib/"
cp -R "${ROOT}/config/." "${RUNTIME}/config/"
cp "${ROOT}/VERSION" "${RUNTIME}/" 2>/dev/null || true
cp "${ROOT}/desktop/distribution/HYPERCLUSTER-EULA.txt" "${APP}/Contents/Resources/"
"${ROOT}/scripts/macos/ensure-app-icon.sh" "$APP"
echo "→ Bundled hypercluster CLI runtime into .app"

python3 "${ROOT}/scripts/macos/generate-eula-rtf.py"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "${DIST}/EULA.rtf" "${STAGE}/"
cp "${DIST}/Welcome.html" "${STAGE}/"
cp "${DIST}/Conclusion.html" "${STAGE}/"
cp "${DIST}/Distribution.xml" "${STAGE}/"

echo "→ Building component pkg…"
pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier dev.hypercluster.desktop \
  --version "$VERSION" \
  --scripts "${ROOT}/scripts/macos/pkg-scripts" \
  "${STAGE}/Hypercluster-component.pkg"

echo "→ Building product pkg with Zyvor license pane…"
productbuild \
  --distribution "${STAGE}/Distribution.xml" \
  --resources "${STAGE}" \
  --package-path "${STAGE}" \
  "$PKG_OUT"

echo ""
echo "✅ ${PKG_OUT}"
echo "   Install: open \"${PKG_OUT}\"  (shows Zyvor EULA in macOS Installer)"
echo "   Or:      ./scripts/macos/install-hypercluster-app.sh \"${APP}\""
