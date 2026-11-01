#!/bin/bash
# Builds App/AppIcon.icns from docs/images/logo.svg. Needs Google Chrome to
# render the SVG; the result is committed, so this only reruns if the logo changes.
set -euo pipefail
cd "$(dirname "$0")/.."

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
work=$(mktemp -d -t kbsync-icon)
trap 'rm -rf "$work"' EXIT

# Apple's icon grid: the artwork is 824 px inside a 1024 px canvas.
cat > "$work/icon.html" <<HTML
<html><body style="margin:0;width:1024px;height:1024px;display:flex;align-items:center;justify-content:center;background:transparent">
<img src="file://$PWD/docs/images/logo.svg" width="824" height="824"></body></html>
HTML
"$chrome" --headless --disable-gpu --allow-file-access-from-files --hide-scrollbars \
    --default-background-color=00000000 --window-size=1024,1024 \
    --screenshot="$work/icon_1024.png" "file://$work/icon.html" 2>/dev/null

mkdir "$work/AppIcon.iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size "$work/icon_1024.png" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$work/icon_1024.png" --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o App/AppIcon.icns
echo "wrote App/AppIcon.icns"
