#!/usr/bin/env sh
set -e
cd "$(dirname "$0")/.."

version=$(flutter --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin)["frameworkVersion"])')
if [ "$version" = 3.38.9 ]; then
  echo "tool/forward.sh checks a Flutter newer than the floor. Put one on PATH." >&2
  exit 64
fi
echo "Flutter $version"

for member in $(./tool/members.sh); do rm -rf "$member/build"; done
./tool/get.sh upgrade > /dev/null
dart analyze --fatal-infos .
for package in examples/codegen_basics examples/notes_app compat/external_consumer; do
  (cd "$package" && dart run build_runner build --delete-conflicting-outputs)
done
git diff --exit-code -- '*.g.dart'
./tool/test.sh

cat <<'DONE'

forward: green. The lock files now hold what this SDK resolved. Back on the
floor, with Flutter 3.38.9 on PATH:

  for m in $(./tool/members.sh); do rm -rf "$m/build"; done
  ./tool/get.sh upgrade
DONE
