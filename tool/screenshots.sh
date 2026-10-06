#!/usr/bin/env sh
# Retakes the README screenshots on the iOS Simulator, through `mac-sim`.
#
#   tool/screenshots.sh              all six
#   tool/screenshots.sh flow env     just those
#
# The gateway has no taps, and a `cobaltgallery://` link opened from outside
# stops at iOS's "Open in Gallery?" prompt, which nothing here can answer. So
# the gallery stages the shots itself: examples/gallery/integration_test/
# screenshots_test.dart opens each one on the Simulator exactly as its link
# would (examples/gallery/lib/app/shots.dart), in a fresh app, prints
# `COBALT_SHOT <name>` once it is on screen and holds it; this takes the picture
# on that line. A shot not named on the command line is staged and skipped.
#
# Needs Remote Login on in the Mac's sharing settings. The Mac builds with its
# own Flutter, which may be newer than the floor: fine for a picture, and the
# reason a screenshot is never evidence that the floor works.
set -e
cd "$(dirname "$0")/.."

DEVICE=${DEVICE:-$(mac-sim devices | awk 'NF{print $1; exit}')}
SIZE=552x1200
# mac-sim takes paths relative to the shared projects directory.
REPO=${PWD#/workspace/ai/projects/}

SHOTS=${*:-hub tree log flow flowlog env}
CR=$(printf '\r')

mac-sim locale en_US "$DEVICE"
mac-sim appearance dark "$DEVICE"
mac-sim statusbar "$DEVICE"

# The pipeline's status is the loop's, so a failed run shows up as a picture
# that did not change.
stamp=$(mktemp)
trap 'rm -f "$stamp"' EXIT

mac-sim test "$REPO/examples/gallery" integration_test/screenshots_test.dart "$DEVICE" 2>&1 |
  while IFS= read -r line; do
    case $line in
      *COBALT_SHOT\ *) shot=${line##*COBALT_SHOT } ;;
      *) continue ;;
    esac
    shot=${shot%"$CR"}
    case " $SHOTS " in *" $shot "*) ;; *) continue ;; esac
    # ssh would otherwise read the rest of the test's output as its stdin.
    mac-sim screenshot "$REPO/assets/screenshots/$shot.png" "$DEVICE" "$SIZE" </dev/null >/dev/null
    echo "$shot: assets/screenshots/$shot.png"
  done

missing=
for shot in $SHOTS; do
  [ assets/screenshots/$shot.png -nt "$stamp" ] || missing="$missing $shot"
done
[ -z "$missing" ] || { echo "Not taken:$missing"; exit 1; }
