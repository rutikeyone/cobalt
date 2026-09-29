#!/usr/bin/env sh
# What changed in each package's public API since the version on pub.dev.
#
#   tool/api.sh            # every package
#   tool/api.sh cobalt     # one
#
# dart_apitool compares the checkout with the latest published release and
# names each change breaking or not, with the version step it would need. It
# is a report, not a gate: before 1.0 every release is a minor step anyway,
# and the tool cannot see everything — it did not flag CobaltResolver turning
# from an interface into a base class, which is breaking for anyone who
# implemented it. Breaking changes are still written into the changelog by
# hand; this catches the ones nobody noticed.
set -eu
cd "$(dirname "$0")/.."
command -v dart-apitool > /dev/null || dart pub global activate dart_apitool > /dev/null

packages=${1:-$(for p in packages/*/pubspec.yaml; do basename "$(dirname "$p")"; done)}
for package in $packages; do
  published=$(curl -fsS "https://pub.dev/api/packages/$package" |
    sed -n 's/.*"latest":{"version":"\([^"]*\)".*/\1/p')
  echo "== $package: checkout against $published on pub.dev"
  if [ -z "$published" ]; then
    echo "   not on pub.dev yet — nothing to compare against"
    continue
  fi
  dart-apitool diff \
    --old "pub://$package/$published" \
    --new "packages/$package" \
    --version-check-mode none 2>&1 |
    sed -n '/Generating report/,$p' | sed '1d'
done
