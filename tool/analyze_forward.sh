#!/usr/bin/env sh
set -u
cd "$(dirname "$0")/.."

status=0
out=$(dart analyze --format=machine --no-fatal-warnings . 2>&1) || status=$?
if [ "$status" -gt 3 ]; then
  printf '%s\n' "$out"
  echo "dart analyze stopped with exit code $status" >&2
  exit "$status"
fi

left=$(printf '%s\n' "$out" | awk -F'|' '
  /^(ERROR|WARNING|INFO)\|/ {
    if (tolower($3) == "deprecated_member_use" &&
        $0 ~ /package:(material_ui|cupertino_ui)\//) {
      moved++
    } else {
      print
    }
  }
  END {
    if (moved) {
      printf "Left out %d deprecation(s) of the move to material_ui and cupertino_ui.\n", moved > "/dev/stderr"
    }
  }
')

if [ -n "$left" ]; then
  printf '%s\n' "$left"
  exit 1
fi
echo "No issues found."
