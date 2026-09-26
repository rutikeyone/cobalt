#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."
command=get
[ "$1" = upgrade ] && command=upgrade
flutter pub "$command"
for member in $(./tool/members.sh); do
  echo "== $member"
  (cd "$member" && flutter pub "$command")
done
