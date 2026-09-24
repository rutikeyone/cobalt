#!/usr/bin/env sh
# Line coverage of the publishable packages, per package and in total.
#
# The floor is on the total rather than per package on purpose. Coverage here
# is measured per package while the code is shared: `cobalt_analyzer`'s parsers,
# for instance, are driven far more from `cobalt_generator`'s tests and from
# `compat/external_consumer` than from their own suite, so a per-package floor
# would demand tests written where they do not belong. The total moves only
# when the repository as a whole tests less than it did.
set -e
cd "$(dirname "$0")/.."

FLOOR=${COVERAGE_FLOOR:-85}
OUT=$(mktemp -d)

DART_PACKAGES="cobalt cobalt_analyzer cobalt_generator cobalt_lint cobalt_test cobalt_talker cobalt_logging cobalt_logger"
FLUTTER_PACKAGES="cobalt_flutter cobalt_go_router cobalt_inspector"

for package in $DART_PACKAGES; do
  (
    cd "packages/$package"
    dart test --coverage="$OUT/raw_$package" >/dev/null
    dart pub global run coverage:format_coverage \
      --lcov --in="$OUT/raw_$package" --out="$OUT/$package.lcov" \
      --report-on=lib --packages=.dart_tool/package_config.json >/dev/null
  )
done

for package in $FLUTTER_PACKAGES; do
  (
    cd "packages/$package"
    flutter test --coverage >/dev/null
    cp coverage/lcov.info "$OUT/$package.lcov"
  )
done

python3 - "$OUT" "$FLOOR" <<'PY'
import glob, os, re, sys

# gen-l10n output: `<name>_l10n.dart` plus one `<name>_l10n_<locale>.dart` per
# language. Not measured, because nobody writes it and nobody can test it: it
# is a thousand lines of getters that would report as poorly covered however
# well the screens reading them are tested, and would then push the floor down
# for everyone else. Hand-written neighbours in the same folder still count —
# `inspector_strings.dart` is the fallback logic, and it is the part a test
# has to reach.
GENERATED = re.compile(r'.*_l10n(_[A-Za-z0-9_]+)?\.dart$')

out, floor = sys.argv[1], float(sys.argv[2])
total_hit = total = 0
rows = []
for path in sorted(glob.glob(os.path.join(out, '*.lcov'))):
    hit = count = 0
    measured = True
    for line in open(path):
        if line.startswith('SF:'):
            measured = not GENERATED.match(line.strip()[3:])
        elif measured and line.startswith('DA:'):
            count += 1
            if int(line.strip().split(',')[1]) > 0:
                hit += 1
    if not count:
        continue
    rows.append((os.path.basename(path)[:-5], hit, count))
    total_hit += hit
    total += count

width = max(len(name) for name, _, _ in rows)
for name, hit, count in sorted(rows, key=lambda row: row[1] / row[2]):
    print(f'{name:<{width}}  {hit:5}/{count:<5}  {100 * hit / count:5.1f}%')

percent = 100 * total_hit / total
print(f'{"total":<{width}}  {total_hit:5}/{total:<5}  {percent:5.1f}%  (floor {floor:.0f}%)')
if percent < floor:
    print(f'\ncoverage fell below the floor: {percent:.1f}% < {floor:.0f}%')
    sys.exit(1)
PY
