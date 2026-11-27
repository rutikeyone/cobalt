import os
import pathlib
import re
import sys

VERSION = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")
DECLARED = re.compile(r"^version: *(\S+) *$", re.M)
INTERNAL = re.compile(r"^(  cobalt[a-z_]*: )\^((\d+)\.\S*)$", re.M)
SKIPPED_DIRS = {"build"}
SKIPPED_FILES = {"CHANGELOG.md", "pubspec_overrides.yaml"}


def major(version: str) -> int:
    return int(version.split(".", 1)[0])


def moves(constraint: re.Match, version: str, old_major: int) -> bool:
    same_major = int(constraint.group(3)) == old_major
    return same_major and (major(version) != old_major or "-" in constraint.group(2))


def bump_pubspec(pubspec: pathlib.Path, version: str, old_major: int) -> None:
    text = DECLARED.sub(f"version: {version}", pubspec.read_text(encoding="utf-8"), count=1)
    text = INTERNAL.sub(
        lambda it: f"{it.group(1)}^{version}" if moves(it, version, old_major) else it.group(0),
        text,
    )
    if pubspec.parent.name == "cobalt_generator":
        text = re.sub(r"^(  cobalt: ).*$", rf"\g<1>^{version}", text, count=1, flags=re.M)
    pubspec.write_text(text, encoding="utf-8")


def head_changelog(changelog: pathlib.Path, version: str) -> None:
    lines = changelog.read_text(encoding="utf-8").splitlines(keepends=True)
    if any(re.match(rf"^## {re.escape(version)}\s*$", line) for line in lines):
        return
    first = next((i for i, line in enumerate(lines) if line.startswith("## ")), len(lines))
    lines[first:first] = [f"## {version}\n", "\n"]
    changelog.write_text("".join(lines), encoding="utf-8")


def documents(root: pathlib.Path, bumped: set[pathlib.Path]):
    for directory, subdirectories, files in os.walk(root):
        subdirectories[:] = sorted(
            name for name in subdirectories if not name.startswith(".") and name not in SKIPPED_DIRS
        )
        for name in sorted(files):
            path = pathlib.Path(directory) / name
            if path.suffix not in {".md", ".yaml"} or name in SKIPPED_FILES or path in bumped:
                continue
            yield path.relative_to(root), path


def report_documents(root: pathlib.Path, bumped: set[pathlib.Path], old_major: int) -> None:
    pattern = re.compile(rf"\bcobalt[a-z_]*: *\^{old_major}\.")
    found = [
        f"{relative}:{number}: {line.strip()}"
        for relative, path in documents(root, bumped)
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1)
        if pattern.search(line)
    ]
    if found:
        print(f"Left as they are, still naming ^{old_major}.:")
        print("\n".join(found))


def main() -> int:
    if len(sys.argv) != 2 or not VERSION.match(sys.argv[1]):
        print("usage: version.py X.Y.Z[-pre]", file=sys.stderr)
        return 2
    version = sys.argv[1]
    root = pathlib.Path(__file__).resolve().parent.parent
    pubspecs = sorted((root / "packages").glob("*/pubspec.yaml"))
    current = DECLARED.search((root / "packages" / "cobalt" / "pubspec.yaml").read_text(encoding="utf-8"))
    old_major = major(current.group(1))

    for pubspec in pubspecs:
        bump_pubspec(pubspec, version, old_major)
        head_changelog(pubspec.parent / "CHANGELOG.md", version)

    if major(version) != old_major:
        report_documents(root, set(pubspecs), old_major)
    return 0


if __name__ == "__main__":
    sys.exit(main())
