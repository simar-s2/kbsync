#!/bin/bash
# Turns a camera recording into the README GIF, plus a small MP4 for places
# that play video (GitHub's web editor, social posts).
#
#   scripts/video-to-gif.sh <video> [start-seconds] [duration-seconds]
#   WIDTH=560 FPS=10 scripts/video-to-gif.sh ~/Movies/kbsync.mov 3 10
#
# Writes docs/images/hero.gif and docs/images/hero.mp4 (set OUT to change).
set -euo pipefail

if [ $# -lt 1 ]; then
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
input=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$0")/.."
start=${2:-0}
duration=${3:-12}
width=${WIDTH:-640}
fps=${FPS:-12}
out=${OUT:-docs/images/hero}

# iPhones film HDR by default, which turns grey and washed out as a GIF.
transfer=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 "$input")
if [ "$transfer" = "arib-std-b67" ] || [ "$transfer" = "smpte2084" ]; then
    echo "warning: this is an HDR video; colours will look flat. Turn off HDR Video in the camera settings and refilm." >&2
fi

palette=$(mktemp -t kbsync-palette).png
trap 'rm -f "$palette"' EXIT

# A light denoise first: camera grain changes every frame and makes GIFs huge.
filters="fps=$fps,scale=$width:-2:flags=lanczos,hqdn3d=3:2:4:4"
ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" \
    -vf "$filters,palettegen=max_colors=200:stats_mode=diff" "$palette"
ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" -i "$palette" \
    -lavfi "$filters [video]; [video][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$out.gif"

ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" \
    -vf "scale='min(1280,iw)':-2:flags=lanczos,format=yuv420p" \
    -c:v libx264 -crf 23 -preset slow -movflags +faststart -an "$out.mp4"

if command -v gifsicle >/dev/null; then
    gifsicle -O3 --lossy=40 -b "$out.gif"
fi

ls -lh "$out.gif" "$out.mp4" | awk '{print $5, $9}'
size=$(stat -f %z "$out.gif")
if [ "$size" -gt 10000000 ]; then
    echo "The GIF is over 10 MB and will load slowly on GitHub. Try a shorter clip, WIDTH=560 or FPS=10." >&2
    command -v gifsicle >/dev/null || echo "brew install gifsicle also shrinks it by about a third." >&2
fi
