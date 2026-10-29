# 2026-10-29 — The missing-PyYAML hint stops prescribing an install route

A medium review of the interpreter-routed hint (see
[the entry](2026-10-29-frontmatter-hint-by-install.md)) found that telling a
venv from everything else still misroutes pyenv, conda, deadsnakes and macOS
Command Line Tools interpreters to a Debian package that cannot reach them. It
was the fourth round on the same message, each finding a new interpreter case.
The message now names the interpreter that failed and asks for PyYAML to be
installed for it, without prescribing how; the right route depends on how that
interpreter was installed, which the gate cannot reliably tell.

Declined as low severity: the user-site note in the venv branch and the bare
`python3` fallback in a `pip` command, both gone with the routing.
