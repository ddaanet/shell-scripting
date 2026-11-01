## Remaining

- inbox/README.md says a declined brief has its reason recorded but not where; now that the changelog is retired, name the commit body (low review finding on eb6901e, optional).
- The ddaanet memory fact `bash32-macos-traps` says the 3.2 traps are in `portability.md`; the bash 3.2 ones moved to `shell-versions.md`. Fix the pointer.
- Run `tests/bash32-lint.bats` on a Mac: the bash 3.2 lint has run only under mawk, and whether macOS awk accepts its `[^\001-\177]` byte range is unverified (a failure now surfaces as a `[bash32-0]` finding).
