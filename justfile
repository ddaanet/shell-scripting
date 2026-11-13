import 'plugin-dev/release.just'

precommit: check-refs check-size check-frontmatter check-modes
    jq . .claude-plugin/plugin.json > /dev/null
    command -v rumdl >/dev/null || { printf '%s\n' 'precommit: rumdl not on PATH; run uv sync, then direnv allow' >&2; exit 1; }
    rumdl fmt --check -q --no-cache .
    shellcheck hooks/scripts/*.sh tests/*.bats tests/*.bash
    command -v bats >/dev/null || { printf '%s\n' 'precommit: bats not on PATH' >&2; exit 1; }
    bash plugin-dev/run-bats.sh tests/*.bats

prerelease: precommit
