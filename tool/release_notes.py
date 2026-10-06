import pathlib
import re
import sys


def entry(changelog: pathlib.Path, version: str) -> str | None:
    lines = changelog.read_text(encoding="utf-8").splitlines()
    heading = re.compile(rf"^## {re.escape(version)}\s*$")
    start = next((i for i, line in enumerate(lines) if heading.match(line)), None)
    if start is None:
        return None
    body = []
    for line in lines[start + 1 :]:
        if line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body).strip()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: release_notes.py <version>", file=sys.stderr)
        return 2
    version = sys.argv[1]
    root = pathlib.Path(__file__).resolve().parent.parent
    packages = sorted(
        (p.parent.name for p in (root / "packages").glob("*/CHANGELOG.md")),
        key=lambda name: (name != "cobalt", name),
    )

    groups: dict[str, list[str]] = {}
    missing = []
    for name in packages:
        text = entry(root / "packages" / name / "CHANGELOG.md", version)
        if not text:
            missing.append(name)
            continue
        groups.setdefault(text, []).append(name)

    if missing:
        for name in missing:
            print(f"packages/{name}/CHANGELOG.md has no '## {version}' entry", file=sys.stderr)
        return 1

    sections = [f"## {', '.join(names)}\n\n{text}" for text, names in groups.items()]
    print("\n\n".join(sections))
    return 0


if __name__ == "__main__":
    sys.exit(main())
