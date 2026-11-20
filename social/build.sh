#!/usr/bin/env bash
# Render social/*.png from social/src/card.html (apple-dark palette). Needs Google Chrome.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; CH="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
r(){ # mode w h out disp
  sed "s/MODE/$1/;s/DISP/$5/" "$H/src/card.html" > "$H/src/_$1.html"
  "$CH" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=$2,$3 --screenshot="$4" "file://$H/src/_$1.html" >/dev/null 2>&1
  rm "$H/src/_$1.html"; }
r wide 1200 630 "$H/og.png" ""
r wide 1280 640 "$H/social-preview.png" ""
r sq 1080 1080 "$H/square.png" ""
r dg 1000 760 "$H/../docs/img/hypercluster-social.png" "display:none"
cp "$H/og.png" "$H/social-preview.png" "$H/square.png" "$H/../site/social/"
