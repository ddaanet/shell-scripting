import 'plugin-dev/release.just'

precommit:
    jq . .claude-plugin/plugin.json > /dev/null
    shellcheck hooks/scripts/shellcheck-on-edit.sh
