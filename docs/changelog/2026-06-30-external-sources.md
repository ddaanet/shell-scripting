# 2026-06-30 — Lint invocation follows external sources (v0.3.0)

`shellcheck -f gcc` became `shellcheck -x -f gcc`. With `-x`
(`--external-sources`) shellcheck follows `source` and `.` directives into the
sourced files and checks them in context, instead of emitting SC1091 "not following:
file not found" for every helper a script pulls in.

Scoped to files resolvable relative to the script and the working directory — no
config file, no extra writes, so the minimal-footprint requirement holds (reads
only). `-x` is BSD/macOS-safe and stable across shellcheck 0.7–0.10.

Re-linted the hook (clean) and exercised it on a clean payload (exit 0).
