#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."
for member in $(./tool/members.sh); do
  [ -d "$member/test" ] || continue
  echo "== $member"
  if grep -q '^  flutter_test:' "$member/pubspec.yaml"; then
    (cd "$member" && flutter test)
  elif [ "$member" = packages/cobalt_analyzer ]; then
    (cd "$member" && dart test -j 1)
  else
    (cd "$member" && dart test)
  fi
done
