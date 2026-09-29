#!/usr/bin/env sh
# Runs the tests of the three analyzer-facing packages against one analyzer.
#
#   tool/matrix.sh 10.0.1 | 12.1.0 | 13.3.0 | 14.4.0
#
# cobalt_analyzer, cobalt_generator and cobalt_lint accept analyzer
# ">=10.0.1 <15.0.0", and its API breaks between 12 and 13. A normal resolve
# only ever tests one row — the floor lands on 12.1.0, `forward` on whatever is
# newest — so this tests any row, on the Flutter that is on PATH.
#
# The version is chosen by an exact `analyzer:` constraint, not by
# `dependency_overrides`. analysis_server_plugin, analyzer_plugin,
# analyzer_testing and dart_style each pin the analyzer they were built
# against; an override switches that check off, so pub keeps the companions of
# some other row and the run tests a combination no consumer can resolve. With
# a constraint, pub picks the companions a consumer on that row would get —
# see the table in RELEASING.md.
#
# The packages are copied, so nothing in the checkout changes. They sit under
# packages/ in a scratch directory next to links to the root READMEs and
# guides, because documented_rules_test reads those by a relative path.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)

row=${1:-}
case "$row" in
  10.0.1 | 12.1.0) min_dart=10 ;;
  13.3.0 | 14.4.0) min_dart=11 ;;
  *)
    echo "usage: tool/matrix.sh 10.0.1|12.1.0|13.3.0|14.4.0" >&2
    exit 64
    ;;
esac

# analyzer 13 and 14 need `_fe_analyzer_shared` releases that require Dart
# 3.11; on the floor they cannot resolve, and saying so beats solver output.
dart_minor=$(dart --version 2>&1 | sed -n 's/.*version: 3\.\([0-9]*\)\..*/\1/p')
if [ -z "$dart_minor" ] || [ "$dart_minor" -lt "$min_dart" ]; then
  echo "analyzer $row needs Dart 3.$min_dart or newer; this is $(dart --version 2>&1)." >&2
  echo "Put a newer Flutter on PATH." >&2
  exit 64
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/packages"
for doc in "$root"/README*.md "$root"/GUIDE_*.md; do ln -s "$doc" "$work/"; done

copied="cobalt_analyzer cobalt_generator cobalt_lint"
for package in $copied; do
  dir="$work/packages/$package"
  cp -R "$root/packages/$package" "$dir"
  rm -rf "$dir/.dart_tool" "$dir/pubspec.lock" "$dir/build"
  # Exactly this analyzer, as a direct dependency of every copy — including
  # cobalt_generator, which otherwise takes it only through cobalt_analyzer.
  # awk rather than sed -i: the two seds disagree on in-place and on newlines.
  if grep -q '^  analyzer:' "$dir/pubspec.yaml"; then
    program='/^  analyzer:/ { print "  analyzer: " row; next } { print }'
  else
    program='{ print } /^dependencies:$/ { print "  analyzer: " row }'
  fi
  awk -v row="$row" "$program" "$dir/pubspec.yaml" > "$dir/pubspec.yaml.new"
  mv "$dir/pubspec.yaml.new" "$dir/pubspec.yaml"
  grep -q "^  analyzer: $row$" "$dir/pubspec.yaml" || {
    echo "could not pin analyzer in $package/pubspec.yaml" >&2
    exit 1
  }
done

status=0
for package in $copied; do
  dir="$work/packages/$package"
  # Siblings by path: the copies for the packages pinned above, the checkout
  # for the rest.
  {
    echo "dependency_overrides:"
    for sibling in cobalt cobalt_annotations cobalt_test $copied; do
      [ "$sibling" = "$package" ] && continue
      case " $copied " in
        *" $sibling "*) path="$work/packages/$sibling" ;;
        *) path="$root/packages/$sibling" ;;
      esac
      echo "  $sibling:"
      echo "    path: $path"
    done
  } > "$dir/pubspec_overrides.yaml"

  echo "== $package on analyzer $row"
  (cd "$dir" && dart pub get > /dev/null)
  (cd "$dir" && dart pub deps --style=compact |
    grep -E '^- (analyzer|analyzer_plugin|analysis_server_plugin|analyzer_testing|dart_style) ') || true
  # cobalt_analyzer's suites each spin up an analysis context; in parallel
  # they starve each other, as in tool/test.sh.
  jobs=""
  [ "$package" = cobalt_analyzer ] && jobs="-j 1"
  # shellcheck disable=SC2086
  (cd "$dir" && dart test $jobs) || status=1
done
exit $status
