# 2026-10-29 — The missing-PyYAML hint names the interpreter

A medium review of the hint correction (see
[the entry](2026-10-29-frontmatter-gate-review-fixes.md)) found that the
Debian and Homebrew packages it named reach only those distributions' default
`python3`, not a pyenv, uv, venv or other `python3` first on `PATH`. The
message now names `sys.executable`, says user site-packages are not searched
only when the interpreter runs isolated, and asks for PyYAML in that
interpreter's own site-packages, which covers a venv.
