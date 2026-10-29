# 2026-10-29 — Corrected the frontmatter check's missing-PyYAML hint

A medium review of the frontmatter gate (see
[the entry](2026-10-29-frontmatter-gate.md)) found that its missing-PyYAML
message told the reader to run `python3 -m pip install pyyaml`, which installs
into user site-packages that `python3 -I` ignores, or fails under PEP 668. The
message now says the module must be installed for that `python3` system-wide
and names the Debian and Homebrew packages.

Declined as low severity: duplicate frontmatter keys passing `safe_load`;
delimiter lines with a BOM or trailing whitespace; a missing `name` reported
twice; the sign-off giving a count rather than the skill names; no fixture test
pinning the rejection; and the check living here rather than in the
claude-plugin-dev toolkit, which a brief in that repo's `inbox/` proposes.
