#!/usr/bin/env sh
# What changed in each package's public API since the version on pub.dev.
#
#   tool/api.sh            # every package
#   tool/api.sh cobalt     # one
#
# dart_apitool compares the checkout with the latest published release and
# names each change breaking or not. From 1.0 on it is a gate: a breaking
# change fails unless the checkout's version is a major step past what is on
# pub.dev (`--version-check-mode onlyBreakingChanges`), so one reaches `main`
# only on its way into a major release. Two things are exempt by design and
# say so in the README's Compatibility section: members marked @experimental
# — dart_apitool itself treats changes there as non-breaking — and
# cobalt_analyzer, internal to the generator and the lint plugin, which is
# reported and never gated.
#
# The tool cannot see everything — it did not flag CobaltResolver turning from
# an interface into a base class. That gap is tool/modifiers.py's: every
# public type's modifiers are kept in tool/class_modifiers.txt, checked in CI.
# Breaking changes are still written into the changelog by hand.
set -eu
cd "$(dirname "$0")/.."
command -v dart-apitool > /dev/null || dart pub global activate dart_apitool > /dev/null

packages=${1:-$(for p in packages/*/pubspec.yaml; do basename "$(dirname "$p")"; done)}
failed=
body=$(mktemp)
trap 'rm -f "$body"' EXIT
for package in $packages; do
  code=$(curl -sS -o "$body" -w '%{http_code}' "https://pub.dev/api/packages/$package") ||
    code=unreachable
  case "$code" in
    200) ;;
    unreachable)
      echo "== $package: FAILED: pub.dev not reachable"
      failed="$failed $package"
      continue
      ;;
    404)
      echo "== $package: not on pub.dev yet — nothing to compare against"
      continue
      ;;
    *)
      echo "== $package: FAILED: pub.dev answered $code"
      failed="$failed $package"
      continue
      ;;
  esac
  published=$(sed -n 's/.*"latest":{"version":"\([^"]*\)".*/\1/p' "$body")
  if [ -z "$published" ]; then
    echo "== $package: FAILED: pub.dev answered without a latest version"
    failed="$failed $package"
    continue
  fi
  echo "== $package: checkout against $published on pub.dev"
  mode=onlyBreakingChanges
  [ "$package" = cobalt_analyzer ] && mode=none
  # Captured rather than piped: sh has no pipefail, and the exit code is the
  # verdict.
  status=0
  report=$(dart-apitool diff \
    --old "pub://$package/$published" \
    --new "packages/$package" \
    --version-check-mode "$mode" 2>&1) || status=$?
  printf '%s\n' "$report" | sed -n '/Generating report/,$p' | sed '1d'
  if [ "$status" -ne 0 ]; then
    echo "   FAILED: a breaking change without a major version step (exit $status)"
    failed="$failed $package"
    # Job logs need admin rights to download; an annotation is public, so the
    # reason is readable from the check run by anyone.
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
      why=$(printf '%s\n' "$report" | grep -i 'breaking' | head -20 |
        sed 's/%/%25/g' | awk '{printf "%s%%0A", $0}')
      echo "::error title=api: $package::${why:-dart-apitool exited $status}"
    fi
  fi
done

if [ -n "$failed" ]; then
  echo
  echo "API check failed:$failed"
  echo "For a breaking change: make it non-breaking, mark it @experimental if it"
  echo "is not part of the stable API, or release it as a major version. See"
  echo "RELEASING."
  exit 1
fi
