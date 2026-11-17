# Gate and Recipe Design

How a cached gate stays honest, what belongs in a shared bash prolog, and how to
speed up a slow gate. These are design questions rather than parse traps: they
come up when adding a check to a gate, splitting one out, or touching the
prolog.

## A gate's cache hash covers every check's inputs

When a gate caches its verdict against a hash of its inputs, the hash has to
cover the union of what **every** check reads, not the paths most of them read.
A check whose scope exceeds the hash can be turned red by a file the hash
ignores, and the red then appears at whatever unrelated moment something else
invalidates the cache. A cached pass is a claim that the checks would still
pass; when a check reads outside the hash the claim is false, and the delay
between cause and symptom is unbounded: whoever sees the red did not write the
code that broke it.

The shape it takes: a gate hashed `justfile`, `pyproject.toml`, `uv.lock`,
`scripts`, `src` and `tests`; its type checker and formatters were scoped to
`src` and `tests`, but `ruff check` took no path argument and linted the whole
project. Scripts landed in another directory with 31 lint errors, never
invalidated the cache, and the commit that introduced them reported green. The
failure surfaced days later, on a one-line edit elsewhere.

For each check in a gated recipe, ask which paths it actually reads and
reconcile that against the hash. Three fixes, chosen by what the check is for:

- **Narrow** the check to match the hash (add the path argument, or exclude the
  tree) when the extra tree was never meant to meet that standard, such as
  prototypes or calibration scripts. Prefer it to widening when either would do:
  a broader hash means more spurious invalidation.
- **Widen** the hash when the check is new and its inputs belong to the package:
  a bats suite over `hooks/` added to the gate needs `hooks` in the hash, and
  `bats --version` folded into it too, or a tool upgrade keeps serving a stale
  pass (the vendored claude-plugin-dev toolkit takes tool versions in
  `PLUGIN_DEV_GATE_TOOLS`). The test is whether the check should see those files
  at all, not whether the hash gets broader.
- **Split** when costs inside one gate differ by orders of magnitude: give the
  offending check its own recipe and sentinel, and make the expensive gate
  depend on it. A 2 s suite over skill prose does not belong in the cache of a 7
  min suite whose hash deliberately excludes that prose; widening would make
  every prose edit pay the full suite, and narrowing is unavailable when reading
  those files is the check's whole job.

Two constraints on a split. Declare the new gate's inputs as everything **its**
check reads, not only the paths the other gate misses: the narrow version is
right only while the other set stays as drawn, and nothing states that
dependency. And make it its own recipe, not a second guard in the same body: the
toolkit's `check-sentinel` sets shell variables that `record-sentinel` reads
back, so it refuses a second gate in one recipe body, which would clobber the
first's state; a hand-rolled pair of helpers passing state the same way clobbers
it silently.

**An input that is a submodule gitlink defeats all three.** Narrow, widen and
split assume the hash can see the tree. A gitlink gives `git ls-files` one path
and nothing to read: the toolkit hashes it by name only, so neither an edit
inside it nor a new commit of it moves the hash. A check over such a tree,
cached behind the sentinel, is skipped on exactly the commits that edit it: it
goes **green on the very commit the check exists for**, and nothing ever
surfaces it, the opposite direction from the under-covered hash above. Run that
check uncached, ahead of the sentinel short-circuit; a check cheap enough to
read one submodule rarely has anything worth caching.

Whichever fix applies, **prove the coverage** rather than reason about it: run
the gate twice to see the cached verdict, append a throwaway line to a file in
the newly covered tree, confirm the next run does real work, then remove the
line and confirm `git diff` on that file is empty.

## A shared bash prolog holds common foundations only

A justfile's shared `bash_prolog` (a just variable holding shell code,
interpolated at the top of each shebang recipe) earns a function only when the
function has two or more call sites. Anything called once is inlined into the
recipe that calls it, including the tempting `run-<recipe>` wrapper that holds a
whole recipe body. The prolog is copied between projects, so every function in
it is something the next project inherits and has to understand; a single-use
function there buys indirection and hides the recipe's shape from whoever reads
the recipe.

- Early exit is `exit` **in the recipe**, never `return` from a `run-<recipe>`
  helper.
- Setup such as a dependency `sync` is called once at recipe toplevel, not from
  inside a helper several recipes reach: otherwise a recipe that depends on
  another calls it twice.
- A helper written for reuse across projects is the one exception to the
  two-call-site rule: parameterize it (the toolkit's
  `check-sentinel <gate> <pathspec>...`, which keeps one sentinel per gate name
  under the git dir) and say so in a comment.

After editing a prolog, count call sites per function and inline the singletons.
When a recipe grows a helper, ask whether a second recipe will call it before
promoting it out of the body. A gate recipe built on the prolog ends by printing
the list of checks that passed, never a bare "OK".

## Speeding up a slow gate

When a gate is slow because it repeats an expensive unit of work many times (a
test suite forking hundreds of git subprocesses per fixture), parallelism
(`bats --jobs`, `make -j`, `xargs -P`) is a legitimate part of the fix but not
enough on its own. Pair it with cutting the per-repetition cost (cache, template
or memoize the repeated work). Neither substitutes for the other, and a fix that
pays off only with spare cores loses its value on a machine scaled down to one.

Measure before choosing the target. A model built from counting call sites and
forks per call is a hypothesis, not a measurement: caching a fixture helper with
about 280 call sites made the helper three times cheaper per call and left the
whole gate's wall-clock unchanged, because the helper was never the dominant
cost. Per-test timing (`bats --timing`, or wall-clock before and after on the
*whole* gated command) found two tests that dominated, which neither the model
nor the cache had touched; fixing those cut the gate by about a fifth.
