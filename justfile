import 'plugin-dev/release.just'

precommit: check-refs
    jq . .claude-plugin/plugin.json > /dev/null
    python3 -I scripts/check-frontmatter.py
    command -v rumdl >/dev/null || { printf '%s\n' 'precommit: rumdl not on PATH; run uv sync, then direnv allow' >&2; exit 1; }
    rumdl fmt --check -q --no-cache .
    sh scripts/check-size.sh
    shellcheck hooks/scripts/shellcheck-on-edit.sh scripts/check-size.sh

prerelease: precommit
