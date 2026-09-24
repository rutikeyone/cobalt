#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."
for pubspec in packages/*/pubspec.yaml examples/*/pubspec.yaml compat/*/pubspec.yaml; do
  [ -f "$pubspec" ] && dirname "$pubspec"
done
