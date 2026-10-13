#!/usr/bin/env bash
#
# Cuts an App Store app preview from the raw screen recording.
#
# Connect wants 15–30s, 30fps, H.264, at the device's own pixel size — which is
# what the simulator recorded, so this trims the launch off the front and
# speeds the take up to fit. The speed-up is not a trick: XCUITest takes about
# two seconds per key tap, so playing the take at ~2.3x is what brings it back
# to the speed a person actually types at.
#
# The optional size (e.g. 1290x2796) rescales the take. Connect's preview slots
# are fussier than its screenshot slots: IPHONE_67 takes screenshots at 6.9"
# (1320x2868) but rejects a preview at that size, so the iPhone preview is
# built at the 6.7" size the slot is named after.
#
#   scripts/build-app-preview.sh <raw.mov> <out.mp4> [start] [duration] [speed] [WxH]
set -euo pipefail

usage="usage: build-app-preview.sh <raw.mov> <out.mp4> [start] [duration] [speed] [WxH]"
src="${1:?$usage}"
dst="${2:?$usage}"
start="${3:-0}"
duration="${4:-29}"
speed="${5:-1}"
size="${6:-}"

final=$(python3 -c "print(f'{$duration / $speed:.2f}')")
if python3 -c "import sys; sys.exit(0 if 15 <= $final <= 30 else 1)"; then
  echo "preview will run ${final}s"
else
  echo "refusing: ${final}s is outside the 15–30s App Store Connect allows" >&2
  exit 1
fi

scale=""
if [ -n "$size" ]; then
  w="${size%x*}"
  h="${size#*x}"
  # Fill the frame, then trim the overflow — the aspect ratios differ by a
  # fraction of a percent, so this crops a few pixels rather than squashing.
  scale=",scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h"
fi

mkdir -p "$(dirname "$dst")"

ffmpeg -y -loglevel error \
  -ss "$start" -t "$duration" -i "$src" \
  -f lavfi -t "$final" -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -map 0:v:0 -map 1:a:0 \
  -filter:v "setpts=PTS/$speed,fps=30${scale:-}" \
  -c:v libx264 -profile:v high -level 4.2 -pix_fmt yuv420p \
  -b:v 12M -maxrate 14M -bufsize 20M \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  "$dst"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,nb_frames:format=duration \
  -of default=noprint_wrappers=1 "$dst"
