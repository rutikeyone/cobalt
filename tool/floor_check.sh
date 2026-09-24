#!/usr/bin/env sh
# Proves the declared floor: every package, the compatibility stand and every
# example resolve, analyse and test on the oldest SDK they claim to support.
#
# It copies them out of the workspace first, and that is the whole reason this
# script exists rather than a few lines in CI. A workspace is one resolution,
# and this one cannot exist on the old SDK: `flutter_test` there pins
# `test_api 0.7.7`, which caps the `test` runner at 1.26.3, which caps
# `analyzer` below 9 — while `cobalt_analyzer` needs 10.0.1 or better. A
# consumer never meets that, because a consumer does not have the `test` runner
# sitting in the same resolution as our analyzer packages. We do. So each
# member is resolved on its own, which is also what pub.dev does when it scores
# them.
#
# The members do not all land on the same analyzer, and that is the point.
# Flutter 3.38 pins `meta 1.17.0`, and analyzer 10.0.2 wants `^1.18.0`, so a
# Flutter package that also has the generator resolves 10.0.1 while a pure-Dart
# one takes 12.1.0. Both ends of that range are exercised here.
#
# Run it with the old SDK first on PATH:
#
#   PATH="$HOME/Flutter/Sdk/flutter_3_38_9_version/flutter/bin:$PATH" ./tool/floor_check.sh
set -e
cd "$(dirname "$0")/.."

ROOT=$PWD
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# name=path, because the members no longer all live under packages/.
DART_MEMBERS="\
cobalt_annotations=packages/cobalt_annotations \
cobalt=packages/cobalt \
cobalt_bloc=packages/cobalt_bloc \
cobalt_talker=packages/cobalt_talker \
cobalt_logging=packages/cobalt_logging \
cobalt_logger=packages/cobalt_logger \
cobalt_test=packages/cobalt_test \
cobalt_analyzer=packages/cobalt_analyzer \
cobalt_generator=packages/cobalt_generator \
cobalt_lint=packages/cobalt_lint \
manual_mode=examples/manual_mode \
teardown=examples/teardown \
cobalt_external_consumer=compat/external_consumer"

FLUTTER_MEMBERS="\
cobalt_flutter=packages/cobalt_flutter \
cobalt_go_router=packages/cobalt_go_router \
cobalt_inspector=packages/cobalt_inspector \
cobalt_talker_flutter=packages/cobalt_talker_flutter \
cobalt_test_flutter=packages/cobalt_test_flutter \
codegen_basics=examples/codegen_basics \
flow_scopes=examples/flow_scopes \
graph_events=examples/graph_events \
notes_app=examples/notes_app \
testing_patterns=examples/testing_patterns \
gallery=examples/gallery"

# The members that run the generator here, one per analyzer row. The stand is
# pure Dart and outside the workspace, so it proves the whole pipeline in the
# arrangement a real consumer has — but being pure Dart it lands on the same
# analyzer as the development SDK. `codegen_basics` is the Flutter one, and it
# is the only place the older row's formatter is ever asked to emit anything.
GENERATES="cobalt_external_consumer codegen_basics"

echo "Dart:    $(dart --version 2>&1)"
echo "Flutter: $(flutter --version 2>&1 | head -1)"
echo

# Each member is checked against the floor it declares, not against a list kept
# here, so raising one package's floor takes it out of this run by name rather
# than silently shrinking what the run covers.
DART_VERSION=$(dart --version 2>&1 | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
ALL=$(python3 "$ROOT/tool/floor_select.py" "$ROOT" "$DART_VERSION" \
  $DART_MEMBERS $FLUTTER_MEMBERS)

for member in $DART_MEMBERS $FLUTTER_MEMBERS; do
  name=${member%%=*}
  case " $ALL " in
    *" $name "*) ;;
    *) printf '%-24s skipped, declares a floor above %s\n' "$name" "$DART_VERSION" ;;
  esac
done

# The copies keep the layout they have here, so a path that reaches out of a
# package means the same thing in both trees. Nothing above them is copied: a
# package that cannot be analysed on its own terms is a package a consumer
# cannot analyse either.
SELECTED=""
for member in $DART_MEMBERS $FLUTTER_MEMBERS; do
  name=${member%%=*}
  path=${member#*=}
  case " $ALL " in *" $name "*) ;; *) continue ;; esac
  SELECTED="$SELECTED $member"
  mkdir -p "$WORK/$path"
  # Everything but the build output, which is large and rebuilt anyway.
  (cd "$ROOT/$path" && tar cf - \
    --exclude build --exclude .dart_tool --exclude coverage .) \
    | (cd "$WORK/$path" && tar xf -)
done

python3 "$ROOT/tool/floor_overrides.py" "$WORK" $SELECTED

failed=""
for member in $SELECTED; do
  name=${member%%=*}
  path=${member#*=}
  case " $FLUTTER_MEMBERS " in
    *" $name="*) get="flutter pub get"; run="flutter test" ;;
    # `-x repo` drops the guards that read the repository around their package:
    # the root documents, the other pubspecs, the CI workflow. They are right
    # to live where they do and cannot run from a copy taken out of the tree.
    # See packages/cobalt/dart_test.yaml and packages/cobalt_lint/dart_test.yaml.
    *) get="dart pub get"; run="dart test -x repo" ;;
  esac

  if [ "$name" = cobalt_analyzer ]; then run="$run -j 1"; fi

  log=$WORK/$name.log
  printf '%-24s ' "$name"

  if ! (cd "$WORK/$path" && $get >"$log" 2>&1); then
    echo "RESOLVE FAILED"; tail -8 "$log"; failed="$failed $name"; continue
  fi

  case " $GENERATES " in
    *" $name "*)
      if ! (cd "$WORK/$path" && dart run build_runner build >>"$log" 2>&1); then
        echo "GENERATE FAILED"; tail -20 "$log"; failed="$failed $name"; continue
      fi
      # The committed output is the claim; regenerating it on the old SDK and
      # finding it unchanged is what turns the claim into a check. This is
      # where the formatter is compared across rows, and formatter drift is
      # what broke CI twice before the range was narrowed.
      #
      # Ours only: `flutter gen-l10n` also writes into `lib/`, and its output
      # differs by a blank line between Flutter releases. That is Flutter's
      # generator disagreeing with itself, not ours, and failing on it would
      # say nothing about Cobalt.
      drift=""
      for generated in $(cd "$WORK/$path" && find lib -name '*.g.dart'); do
        diff "$WORK/$path/$generated" "$ROOT/$path/$generated" >>"$log" 2>&1 \
          || drift="$drift $generated"
      done
      if [ -n "$drift" ]; then
        echo "GENERATED CODE DIFFERS:$drift"; tail -20 "$log"
        failed="$failed $name"; continue
      fi
      ;;
  esac

  if ! (cd "$WORK/$path" && dart analyze --fatal-infos . >>"$log" 2>&1); then
    echo "ANALYZE FAILED"; tail -20 "$log"; failed="$failed $name"; continue
  fi
  if [ ! -d "$WORK/$path/test" ]; then
    echo "ok (resolved, analysed; no tests)"
    continue
  fi
  if ! (cd "$WORK/$path" && $run >>"$log" 2>&1); then
    # The failure body, not the tail: a suite this size ends in progress lines,
    # and `tail` on those says a test failed without saying which or why.
    echo "TESTS FAILED"
    sed -n '/\[E\]/,/^$/p' "$log" | head -30
    sed -n '/^Failing tests:/,$p' "$log" | head -12
    failed="$failed $name"; continue
  fi
  echo "ok (resolved, analysed, tested)"
done

if [ -n "$failed" ]; then
  echo
  echo "Floor not met by:$failed"
  exit 1
fi

echo
echo "Every member meets the floor it declares."
