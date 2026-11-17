# Config and Remotes: Multi-valued Keys, Transport Policy, Submodule Urls

How `git config` reads lie, which transports git refuses, and what a submodule
url looks like once git has stored it. Measured on git 2.47.3.

## Multi-valued keys

- **`git config --get <key>` on a multi-valued key prints the LAST value and
  exits 0.** It does not fail, and gives no sign that other values exist.
- **`git config --unset <key>` on a multi-valued key refuses, status 5.**
- **`--get` on an unset key exits 1**, the status a guard absorbs; `--get-all`
  behaves the same.
- **A config file git cannot parse (`fatal: bad config line`) breaks every git
  call with status 128**, not just `git config`. So no fixture makes
  `git config` fail with another status while the rest of a script still works:
  whether a guard absorbs status 1 only or every failure cannot be pinned by a
  test and has to be checked in code review.

`remote.<name>.pushurl` is genuinely multi-valued, since pushing to several
mirrors is supported, so this is a real configuration, not a corner case. A
guard that refused a redirected push route read it with `--get`, named one of
two push urls, and advised unsetting it: the refusal was right and the remedy
failed with status 5, which is worse than silence, since the operator follows
it. Reading the code does not reveal this: `--get` looks like it returns "the
value".

Read with `--get-all`, list the values one per line in a `hint:` block rather
than interpolating them into a one-line message (a path holding a space must not
read as two), and advise `--unset-all`. State the residual in a comment: a value
containing a newline still prints across two lines, and `git config` has no
quoting mode that avoids it.

## An interpolated key is a regex

`git config -z --get-regexp` is the whitespace-robust enumeration form
([`environments.md`](../../shell-gotchas/references/environments.md), "Parsing
git output"), and it stays that for a *literal*, hand-written pattern. It breaks
once the key is interpolated: the argument is a regex over the key name, and a
branch or remote name legitimately contains `.`, `+`, `$`, `(`, `)`, `|`, `{`,
`}`. Both directions are silent:

- `.` over-matches: `--get-regexp "branch.a.b.merge"` also returns
  `branch.aXb.merge`'s value, status 0, a wrong value with no sign of it.
- `+` under-matches: `--get-regexp "branch.feat+x.merge"` misses the key of
  exactly that name, status 1, indistinguishable from unset.

So interpolate a name only into `--get-all`, which takes the key literally, and
read one value per line. Keep `-z --get-regexp` for patterns written by hand.
Its NUL records survive into a shell through
`while IFS= read -r -d '' rec; do …; done < <(git config -z --get-regexp …)`,
which recovers a value containing spaces, but not through `$( … )`, which
discards NULs.

## Transport policy

### `file`: the child clone decides

`git submodule add -- /path/to/bare.git name` fails with:

```text
fatal: transport 'file' not allowed
```

`protocol.file.allow` defaults to `user`: allowed for a command the user typed,
blocked for one git spawns on their behalf. `submodule add` clones through a
child process, so it is the blocked case; so are `clone --recurse-submodules`
and `submodule update`.

**Setting it in the repository's config does not work.**
`git -C parent config protocol.file.allow always` has no effect, because the
policy is read by the clone, a fresh process in a repository that does not exist
yet, which never reads the parent's config. The setting has to travel on the
command line or in the environment:

- `git -c protocol.file.allow=always submodule add …` when the script owns the
  command line; `-c` reaches child processes through `GIT_CONFIG_PARAMETERS`.
- `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always`,
  exported, when it does not: a test harness exercising production code that
  makes its own git calls. Exported once, it reaches the whole process tree.

Neither form survives a hook's `unset $(git rev-parse --local-env-vars)`: that
list carries `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT` beside `GIT_DIR` and
`GIT_INDEX_FILE`, and without the count the `GIT_CONFIG_KEY_0` pair is ignored.
Put the `-c` on the git call inside the subshell, after the unset
([`environments.md`](../../shell-gotchas/references/environments.md)).

Loosening it is a test-fixture move, not a production one: it is the same
transport-policy dial as `ext` below, and `file` is restricted for a reason.
Reach for it when local bare repositories are the only remotes available (a
sandbox with no network), and scope it to the harness.

### `ext`: off by default

`git-remote-ext` runs a shell command as a transport: a url of the form
`ext::sh -c '…'` is a documented remote-code-execution vector and a standard
finding of automated security review on any code that clones a caller-supplied
url. It is off by default: `protocol.allow` defaults to `never` for
known-dangerous protocols, `ext` among them.
`git submodule add -- "ext::sh -c 'touch X'" p` dies with

```text
fatal: transport 'ext' not allowed
```

and nothing runs. Enabling it takes an explicit `protocol.ext.allow=always`.

So an "ext:: command injection" finding is not exploitable on a default git.
Probe the actual policy before ranking one, and separate the two claims such a
finding usually conflates: shell injection (does the url reach a shell? not if
it is a quoted argument after `--`) and transport selection (which transports
can the url choose?). Only the second is live, and only under a loosened config.

Guard anyway where the clone runs somewhere its caller could not otherwise
reach: a Claude Code hook runs outside the agent's command sandbox, with
network, so a url handed to a hook reaches further than one the agent could use
itself. A scheme allowlist (`http`, `https`, `ssh`, `git`, `file`, scp-like
`[user@]host:path`, local paths) closes the class independently of git config:
reject anything whose text before the first colon is followed by a second colon.

## Submodule urls arrive rewritten

A submodule entry's `url` passes through git before it reaches the submodule's
own `remote.origin.url`, so a marker value planted in `.gitmodules` is not the
string that arrives.

- **No `url` key at all:** `git submodule init`, `update --init` and
  `clone --recurse-submodules` all die with
  `fatal: No url found for submodule path '<path>' in .gitmodules`. Everything
  else is indifferent: `git status`, `git submodule status`, the gitlink, and a
  `git config --file .gitmodules submodule.<name>.path` lookup all work. An
  entry that must stay initializable needs *some* url, which is all a
  placeholder buys.
- **A relative url is absolutized.** `submodule init` and `submodule sync`
  resolve `./.git/marker` against the superproject and store
  `<parent-abs-path>/.git/marker`. An equality test against the spelling written
  into `.gitmodules` matches only a `.gitmodules` read; against
  `remote.origin.url` it is dead code. Match the basename, or read
  `.gitmodules`.
- **A placeholder does not rescue a clone.** `submodule update --init` on one
  fails with `repository '<abs>/.git/marker' does not exist`: the same outcome
  as no url, with a different message.
- **In that state `origin` exists**, so a repair path has to `remote set-url`;
  `remote add` fails.

Before writing a comparison against a sentinel planted in config another tool
owns, run the tool and read back what it stored. A check against the spelling
written passes review, never matches, and silently inverts the branch it guards:
one script read a synced placeholder as a real remote already wired and refused
to create one.
