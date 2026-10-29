"""Fail when a skill's SKILL.md frontmatter is not valid YAML with a name and description.

An unquoted `: ` in a description makes the block invalid YAML, and the
skill then silently fails to load; nothing else in the gate parses it.
"""

import pathlib
import sys

try:
    import yaml
except ImportError:
    sys.exit(
        "check-frontmatter: PyYAML not importable by python3 -I, which ignores"
        " user site-packages; install it system-wide for this python3"
        " (Debian: apt install python3-yaml; Homebrew: brew install pyyaml)"
    )


def main():
    paths = sorted(pathlib.Path("skills").glob("*/SKILL.md"))
    if not paths:
        sys.exit("check-frontmatter: no skills/*/SKILL.md found")
    errors = [e for p in paths for e in check(p)]
    for error in errors:
        print(f"check-frontmatter: {error}", file=sys.stderr)
    if errors:
        sys.exit(1)
    print(f"check-frontmatter: {len(paths)} skills have valid name and description")


def check(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        return [f"{path}: no frontmatter block delimited by ---"]
    block = "\n".join(lines[1 : lines.index("---", 1)])
    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        return [f"{path}: invalid YAML: {exc}".replace("\n", " ")]
    if not isinstance(data, dict):
        return [f"{path}: frontmatter is not a mapping"]
    errors = []
    for key in ("name", "description"):
        if not isinstance(data.get(key), str) or not data[key].strip():
            errors.append(f"{path}: missing or empty {key}")
    if data.get("name") != path.parent.name:
        errors.append(f"{path}: name {data.get('name')!r} != directory {path.parent.name!r}")
    return errors


if __name__ == "__main__":
    main()
