# 2026-06-11 — Initial design and implementation (v0.2.0)

The plugin was created with the plugin-dev workflow plus writing-skills TDD
(`de4d9a2`).

RED: four baseline subagent scenarios ran *without* the skill — write a portable
script, handle hostile filenames, write a submodule `pre-commit` hook, and edit an
existing script carrying a latent GNU-ism. The edit scenario reproduced the gitlore
launcher-shim incident: a `paste -sd:` survived an edit pass despite an explicit
macOS requirement. That finding, not the famous-gotcha list, set the skill's
emphasis.

GREEN: `SKILL.md` (five core rules, gotcha table, platform-simulation pattern) plus
three reference catalogs (`portability.md`, `robustness.md`, `environments.md`);
the same scenarios pass with the skill loaded.

Hook: `shellcheck-on-edit.sh`, detecting shell files by extension or shebang sniff
and feeding findings back through exit 2 + stderr. Behaviourally tested, including
a dash-with-options shebang. Validated by plugin-validator (PASS) and
skill-reviewer (pass — the description was rewritten, the `MultiEdit` matcher
dropped, operational-error separation applied). A one-time missing-shellcheck
`systemMessage` notice was added at the user's request.

Meta-find from the work itself: a comment beginning `# shellcheck …` parses as a
malformed shellcheck directive and fails lint.
