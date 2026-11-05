## Remaining

- `is_shell_file` in `hooks/scripts/shellcheck-on-edit.sh` misses a bats shebang with options: an extensionless file starting `#!/usr/bin/env bats -t` is not linted, while `docs/design.md` promises detection "with or without interpreter options" and the same shape with `bash -e` is linted. The two option-suffix case lines have no `bats` alternative.
