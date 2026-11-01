## Open decisions

- bash 3.2 lint (plans/2026-10-31-bash32-lint-family-brief.md): where the lint lives — an extra grep pass inside hooks/scripts/shellcheck-on-edit.sh, or a separate script/gate — and whether pattern 3 (every `printf -v … '%b'`) is an acceptable false-positive rate.

## Remaining

- Plan and build the bash 3.2 lint once its venue is decided.
- inbox/README.md says a declined brief has its reason recorded but not where; now that the changelog is retired, name the commit body (low review finding on eb6901e, optional).- The ddaanet memory fact `bash32-macos-traps` says the 3.2 traps are in `portability.md`; the bash 3.2 ones moved to `shell-versions.md`. Fix the pointer.
