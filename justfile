import 'plugin-dev/release.just'

precommit: check-refs
    jq . .claude-plugin/plugin.json > /dev/null
    shellcheck hooks/scripts/shellcheck-on-edit.sh

prerelease: precommit
