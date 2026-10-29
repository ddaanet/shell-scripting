---
name: just-gotchas
description: Catalogs `just` recipe pitfalls in interpolation, shebang indentation, and comments. This skill should be used when writing, editing, reviewing, or debugging justfiles or `just` recipes — recipe arguments reaching shell commands, shebang recipe bodies, or "Unknown start of token" and "Expected … but found" parse errors.
---

# just Recipes: Interpolation, Indentation, Comments

Three things about `just` that bite while writing a recipe, none of which a
shell-shaped intuition predicts. Verified against just 1.46.

## Interpolation is raw text, so shell quotes around it protect nothing

A `{{ … }}` substitution is textual, performed on the recipe body *before* any
shell sees it — it is never a shell-level parameter. By the time the shell
parses the line, the argument's own `$(…)`, backticks and quote characters are
part of the source text. So a recipe written as:

```just
run command:
    some-tool --arg c "{{command}}"
```

runs whatever substitution the caller passed and hands the downstream program
something the caller never typed, silently and with exit 0. The double quotes
are shell syntax applied to text that already contains the injection.

Pass any argument that is *data* rather than an identifier through just's
`quote()` function, unquoted at the shell level — `quote()` emits its own
single quotes:

```just
run command:
    some-tool --arg c {{ quote(command) }}
```

This bites wherever a recipe argument reaches a program that interprets it: a
commit message, a shell command, a path. A `msg='…'` recipe echoing its message
into a file, or a `name=''` recipe testing `[ -n "…" ]`, is the common shape.

This one never surfaces as an error at all; the next two usually do, though
each has a silent case too.

## Every body line of a shebang recipe must share a common leading indent

just strips a common leading indent before executing a shebang recipe, and
lines starting at column 0 — a pasted Python or awk heredoc body, say — are
not exempt. A column-0 line *ends the recipe*: just parses it, and what
follows, as top-level justfile syntax. What just reports then depends on what
the pasted lines happen to look like as justfile syntax, and the reported line
need not be the culprit. Most fail with `Unknown start of token` or `Expected
…`, at the column-0 line or on a line after it; one shaped like a recipe
header (`for x in y:`, `else:`) starts a new recipe, which can raise a
recipe-level error further down. When it raises none, the shebang recipe runs
only the lines above it; on any error, nothing runs. Either indent the whole block uniformly, or
move it to a standalone script the recipe calls.

## Interpolation is parsed inside a recipe body's comment lines too

A `#` comment inside a recipe body is scanned for substitutions, so a comment
written to *describe* interpolation syntax is itself a parse error. What the
braces hold decides how loudly it fails (just 1.46):

- a literal, unresolvable substitution gives `error: Unknown start of token`,
  pointing at the comment;
- an undefined name gives ``error: Variable `x` not defined``;
- **a name already in scope — a parameter of the very recipe the comment sits
  in — is substituted silently.** The comment then acquires the caller's
  argument and says something the author never wrote, while the recipe parses
  and runs.

Only a recipe *body*'s comments are scanned; a file-level comment above the
recipe is inert, literal braces included. Describe interpolation in prose,
without the brace characters, wherever the comment sits.

## Diagnosing a parse error

The last two usually surface as a parse error whose reported line looks
inert or is ordinary embedded code, which invites blaming the embedded
language. A comment-interpolation error points at the comment itself; for an
indentation error, whatever the message, look for a column-0 line anywhere in
the recipe body above the reported line, not only on the line itself.
Concluding that embedded Python in a recipe was at fault and rewriting it in
`jq` wasted an iteration: the language was fine, the indentation was the bug.

When a shebang recipe fails to parse, or runs only its first lines, check the
indent of every body line and the braces in every comment **before** touching
the embedded script. When nothing errors, `just --dump` shows where the recipe
ends; on a parse error it prints only the error. When a recipe
takes an argument, decide whether it is an identifier or data, and wrap the
data in `quote()`.
