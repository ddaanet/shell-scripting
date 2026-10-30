#!/bin/sh
# Oversized-file gate: .md, .sh and .py files over their line cap fail.
# Cap: 200 for skills/*/SKILL.md hubs, 400 for everything else.
# Run from the repo root inside a git work tree. Untracked, non-ignored files
# are included, so a new file is checked before `git add`.
# Excluded, as in .rumdl.toml: plugin-dev/, memory/, plans/, inbox/,
# docs/changelog/, docs/changelog.md, TODO.md, TASK.md. Also .claude/, where
# the command sandbox plants unreadable placeholder files.
# Lines are counted with awk, not wc -l: BSD wc pads its output, and wc -l
# omits a final line that lacks its newline.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    printf '%s\n' 'check-size: not inside a git work tree' >&2
    exit 1
}

# shellcheck disable=SC2016 # the inner script is meant to expand in the child sh
counts=$(
    git ls-files -z --cached --others --exclude-standard |
        xargs -0 sh -c '
            for f do
                case $f in
                    plugin-dev/*|memory/*|plans/*|inbox/*|.claude/*) continue ;;
                    docs/changelog/*|docs/changelog.md|TODO.md|TASK.md) continue ;;
                    *.md|*.sh|*.py) ;;
                    *) continue ;;
                esac
                case $f in
                    skills/*/SKILL.md) cap=200 ;;
                    *) cap=400 ;;
                esac
                n=$(awk "END { print NR }" < "$f") || exit 1
                if [ "$n" -gt "$cap" ]; then
                    printf "%s: oversized-file: %s lines > %s\n" "$f" "$n" "$cap" >&2
                    printf "over\n"
                else
                    printf "ok\n"
                fi
            done
        ' sh
) || { printf '%s\n' 'check-size: failed to count lines' >&2; exit 1; }

checked=$(printf '%s\n' "$counts" | grep -c .)
if [ "$checked" -eq 0 ]; then
    printf '%s\n' 'check-size: no files selected' >&2
    exit 1
fi
over=$(printf '%s\n' "$counts" | grep -c '^over$')
if [ "$over" -gt 0 ]; then
    exit 1
fi
printf 'size: %s files within caps (hub 200, other 400)\n' "$checked"
