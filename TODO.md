## Remaining

- Release review of the bash 3.2 lint work: `/simplify`, then `xhigh`, over the range from the parent of 8263129 to main. Per-commit medium reviews ran on 8263129, 52adedb, 1b212c2, de0b902, 395d422, 6aa71c8, d444d97, 8f39364, db21160 and 8f3c92e; eedbf52, 4080320 and the doc-only fix commits had none. `/simplify` candidate in `scan_locale_prefix`: the `has_tok` condition guards nothing but an array literal, where it causes a miss.
- bash32-3 false positive, found while auditing the lint for the matcher fix: `scan_printf_var` looks for the `b` conversion in everything after the `printf -v` up to the first `&&` or `||`, so `printf -v x '%s' "$v"; printf '%b' z` is flagged, against D11's "`%s` formats are fine". Not fixed.
