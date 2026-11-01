## Remaining

- Review state of the bash 3.2 lint on `main` (8263129..4080320): per-commit medium reviews ran on 8263129, 52adedb and 1b212c2 and de0b902; eedbf52 (doc wording) and 4080320 (TODO) had none. No release review yet.
- bash32-2 misses the quoted assigned substitution `v="$(LC_ALL=C printf %q "$x")"` (the unquoted `v=$(…)` is flagged), contradicting D11 in `docs/references/hook.md`; backtick, `<(` and mid-word openers miss the same way (review of de0b902). Open: extend the `NAME=$(` branch, or make any `$(`, backtick, `<(`, `>(` inside a word open a command position.
