# 2026-10-29 — just-gotchas states the column-0 mechanism, not a list of errors

A medium review of the recipe-header entry (see
[the entry](2026-10-29-just-header-errors.md)) found its newly listed errors
incomplete in turn (a single `for x in x:` gives a duplicate-parameter error,
a single header named like an existing recipe a redefinition), the quoted
redefinition message cut short, and "check the line above the reported one"
wrong for an extra-whitespace error two lines below the culprit. Each round on
this paragraph had enumerated error messages and line offsets, and each review
found another case. The indentation section now states the mechanism: what
just reports depends on what the pasted lines look like as justfile syntax,
the reported line need not be the culprit, and a header-shaped line may raise
a recipe-level error later or none. The diagnosis section, renamed "Diagnosing
a parse error", tells the reader to look for a column-0 line anywhere in the
recipe body above the reported line, whatever the message.

Declined as low severity: the skill description naming only the `Unknown
start of token` and `Expected … but found` errors as triggers; editing a
justfile already triggers it.
