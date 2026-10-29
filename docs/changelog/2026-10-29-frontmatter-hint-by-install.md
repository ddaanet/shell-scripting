# 2026-10-29 — The missing-PyYAML hint picks its fix from the interpreter

A medium review of the interpreter-naming hint (see
[the entry](2026-10-29-frontmatter-hint-interpreter.md)) found that "install it
into that interpreter's own site-packages" sends a Debian or Ubuntu reader on
`/usr/bin/python3` to a `pip install` that PEP 668 refuses, and that the
user-site note keyed on `-I` rather than on user site being off. The hint now
gives `<interpreter> -m pip install pyyaml` inside a venv and the OS package
(Debian: `python3-yaml`) otherwise, adds the user-site note whenever
`sys.flags.no_user_site` is set, and falls back to `python3` when
`sys.executable` is empty.

Declined as low severity: the earlier entry's "covers a venv" (a venv counts
only when its `python3` is first on `PATH`, and the hint names the interpreter
that ran), and the line length of the old conditional, now gone.
