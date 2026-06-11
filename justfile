import 'plugin-dev/release.just'

# Define your project-specific precommit recipe.
# (The release recipe imported above depends on it.)
precommit:
    jq . .claude-plugin/plugin.json > /dev/null
