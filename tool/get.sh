#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."
flutter pub get
for member in $(./tool/members.sh); do
  echo "== $member"
  (cd "$member" && flutter pub get)
done
