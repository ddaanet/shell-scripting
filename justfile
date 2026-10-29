import 'plugin-dev/release.just'

precommit: check-refs
    jq . .claude-plugin/plugin.json > /dev/null
    python3 -I scripts/check-frontmatter.py
    shellcheck hooks/scripts/shellcheck-on-edit.sh

prerelease: precommit
