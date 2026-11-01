#!/bin/bash
# Turns a camera recording into the README GIF, plus a small MP4 for places
# that play video (GitHub's web editor, social posts).
#
#   scripts/video-to-gif.sh <video> [start-seconds] [duration-seconds]
#   WIDTH=440 FPS=10 CROP=1080:1300:0:340 scripts/video-to-gif.sh IMG_1473.MOV 0 9
#
# CROP is ffmpeg's w:h:x:y, in the video's upright pixels. Writes
# docs/images/hero.gif and docs/images/hero.mp4 (set OUT to change).
set -euo pipefail

if [ $# -lt 1 ]; then
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi
# zsh leaves the ~ in `make gif VIDEO=~/...` unexpanded, so expand it here.
input=${1/#\~/$HOME}
if [ ! -f "$input" ]; then
    echo "no such file: $input" >&2
    exit 1
fi
input=$(cd "$(dirname "$input")" && pwd)/$(basename "$input")
cd "$(dirname "$0")/.."
start=${2:-0}
duration=${3:-12}
width=${WIDTH:-520}
fps=${FPS:-12}
out=${OUT:-docs/images/hero}
crop=${CROP:+crop=$CROP,}

work=$(mktemp -d -t kbsync-gif)
trap 'rm -rf "$work"' EXIT
palette=$work/palette.png

# iPhones film HDR by default, which comes out grey and washed out if
# converted naively. avconvert uses Apple's own HDR-to-SDR tone mapping.
transfer=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 "$input")
if [ "$transfer" = "arib-std-b67" ] || [ "$transfer" = "smpte2084" ]; then
    echo "HDR video: converting to SDR with avconvert"
    avconvert --source "$input" --preset Preset1920x1080 --output "$work/sdr.mp4" >/dev/null
    input=$work/sdr.mp4
fi

# Camera grain changes every frame, which defeats GIF compression, and a dark
# room is mostly grain. Denoise, then crush the near-black to pure black: on
# the first real recording that took the GIF from 12 MB to under 5 MB.
filters="fps=$fps,${crop}scale=$width:-2:flags=lanczos,hqdn3d=6:4:10:10,colorlevels=rimin=0.06:gimin=0.06:bimin=0.06"
ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" \
    -vf "$filters,palettegen=max_colors=160:stats_mode=diff" "$palette"
ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" -i "$palette" \
    -lavfi "$filters [video]; [video][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    "$out.gif"

ffmpeg -v error -y -ss "$start" -t "$duration" -i "$input" \
    -vf "${crop}scale='min(1280,iw)':-2:flags=lanczos,format=yuv420p" \
    -c:v libx264 -crf 23 -preset slow -movflags +faststart -an "$out.mp4"

if command -v gifsicle >/dev/null; then
    gifsicle -O3 --lossy=40 -b "$out.gif"
fi

ls -lh "$out.gif" "$out.mp4" | awk '{print $5, $9}'
size=$(stat -f %z "$out.gif")
if [ "$size" -gt 10000000 ]; then
    echo "The GIF is over 10 MB and will load slowly on GitHub. Try a shorter clip, WIDTH=440 or FPS=10." >&2
    command -v gifsicle >/dev/null || echo "brew install gifsicle also shrinks it by about a third." >&2
fi
