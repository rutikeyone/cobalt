#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."

DEVICE=${DEVICE:-$(mac-sim devices | awk 'NF{print $1; exit}')}
REPO=${PWD#/workspace/ai/projects/}
VIDEO=${VIDEO:-/workspace/ai/tmp/quick-tour.mp4}
FPS=${FPS:-8}
START=${START:-1.5}
DURATION=${DURATION:-12}
WIDTH=${WIDTH:-600}

mac-sim locale en_US "$DEVICE"
mac-sim appearance dark "$DEVICE"
mac-sim statusbar "$DEVICE"

rm -f "$VIDEO"
mac-sim test "$REPO/examples/gallery" integration_test/quick_tour_test.dart "$DEVICE" 2>&1 |
  while IFS= read -r line; do
    case $line in
      *COBALT_TOUR\ ready*) mac-sim record start "$VIDEO" "$DEVICE" </dev/null ;;
      *COBALT_TOUR\ done*) mac-sim record stop </dev/null ;;
    esac
  done

[ -f "$VIDEO" ] || { echo "Not recorded: $VIDEO"; exit 1; }
mac-sim gif "$VIDEO" "$PWD/assets/quick-tour.gif" "$FPS" "$START" "$DURATION" "$WIDTH"
