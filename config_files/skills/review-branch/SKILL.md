---
name: review-branch
description: Thorough design and style review of the current branch (or a given branch/PR) of any repository against its base, covering correctness, compatibility, security, design, efficiency, tests, documentation and the repository's own conventions. Loads extra rules for RASR (C++), apptek_asr (Sisyphus jobs, hash stability, artefacts) and AppTalk (services, contracts, migrations, authorization, SPA). Use when asked to review a branch or PR, or invoked as /review-branch.
argument-hint: "[base-branch] [extra focus]"
---

# Branch review

## First: load the repository's rules

Before reading the diff, run `git remote -v` and read the reference file for the repository whose name the remote URL ends in (with or without `.git`; forks and worktrees count):

| Remote repository | Reference |
|---|---|
| `rasr` (e.g. `rwth-i6/rasr`) | `references/rasr.md` |
| `apptek_asr` | `references/apptek_asr.md` |
| `apptalk` | `references/apptalk.md` |

The reference adds rules, finding categories, boundary cases and checks to the sections below, and where it is more specific (e.g. the fallback base branch), it takes precedence. If no remote matches, review with this file alone.

## Scope

Review the changes of the current branch against its base branch. The base branch is the first argument; if none is given, find the PR for the current branch (GitHub or Bitbucket skill) and use its destination branch, otherwise the remote's default branch (`git symbolic-ref refs/remotes/origin/HEAD`), otherwise ask. A PR may be stacked on another PR's branch: review only what the branch adds on top of its destination. Diff with `git diff origin/<base>...HEAD` (fetch first if the remote branch is missing). Read the PR description and comments if available.

Read generated files, vendored code and lockfile diffs only for whether they match their source and for what changed in versions, not line by line.

## Goal: complete once, then stable

The review should find every issue worth fixing in a single run, and a rerun on the same code (or on code where the findings were addressed) should report nothing new. Concretely:

- **Be exhaustive on the first pass** instead of stopping after a handful of findings (see "How to work").
- **"No issues" is a valid and expected answer.** For each question, answer "Yes" in one line when nothing needs to change. Don't search for something to say.
- **Only report what clears the bar** (next section). A finding that would be dropped or reverted in the next round should not be reported in this one.

## Bar for a finding

Report a finding only if it has a concrete consequence that you can name:

- **Bug:** a specific input, configuration, request or call sequence that produces wrong results, a crash or silent misbehavior. Give the example.
- **Security:** a caller who can read or change what they should not, a secret that reaches a log, the environment, a committed file or a client, or an unsafe path that works silently instead of being gated. Name the caller and what they reach.
- **Compatibility:** a change that breaks what already exists outside the diff: callers of a public API, stored or serialized data, file formats, config files, CLI flags, cached or hashed results, a schema migration that the deployed readers cannot follow, or an edit to a migration that has already run somewhere. Name the caller, data or environment affected.
- **Design:** a concrete cost, e.g. a combination with an existing feature that breaks, an invariant callers can violate without an error, duplicated logic that must be kept in sync, a reusable existing helper or pattern that was ignored, a dependency that crosses a boundary the repository draws, an abstraction with a single user.
- **Efficiency:** a measurable cost for a realistic input size (quantify it), e.g. repeated work, one query or request per item where one would do, loading far more than needed, expensive work at import or startup time. Don't report gains that are negligible.
- **Test:** a new or changed behavior, or a fixed bug, that no test would catch breaking; or a test that cannot fail, that only restates the implementation, or that breaks on a change no user would notice (see "Tests"). Name the bug that would go unnoticed or the harmless change that would fail the test.
- **Style/documentation:** a violation of the repository's written conventions (contributing guide, `CLAUDE.md`/`AGENTS.md`, lint and formatter config) or of the rules below and in the repository's reference, a comment, docstring, README or design record that is wrong or misleading, or text that is clearly bloated, i.e. something a reader would actually misunderstand or have to wade through.

Do **not** report:

- A choice between alternatives that are equally readable, correct and efficient (naming variants, ordering of independent statements, helper vs. inline for a one-liner, comment wording that is already accurate). If the current code is one of several equally good options, it is fine.
- Hypothetical problems that require a configuration, caller or data that does not exist and is not plausible, unless the failure would be silent and the guard is a one-line check.
- Anything the repository's tooling fixes automatically (e.g. a formatter or autofix step that CI runs and commits). Only mention lint if the branch would fail a check that is not auto-fixed.
- Limitations the repository already documents as known or out of scope, unless the change claims to remove them, makes them worse, or invalidates what the documented limitation rests on.
- Code the repository marks as personal, experimental or exempt held to the standards of shared code; only flag real bugs there, and dependencies on it from shared code.
- Pre-existing issues in untouched code, unless the change makes them reachable or worse. These may be mentioned in one line at the end as out of scope.
- Points that earlier review rounds or commits on this branch already resolved or deliberately decided (check the branch's `git log`, the PR comments and any design records), unless you have new evidence. A change to what the decision rested on is new evidence: when the branch, or something merged beneath it, alters an assumption a documented decision or deferral relies on, re-check that decision as if it were new. Don't reverse a decision just because the alternative is also reasonable.

## Verify before reporting

- Check each claim against the code: construct the failing example and trace it through, or grep all callers and readers (other modules, other services, tests, scripts, deployment config). If it doesn't fail, drop the finding.
- Check that the suggested fix fits the rest of the design and doesn't introduce a new problem (e.g. a compatibility break, a behavior change for existing users, a case it breaks). If it would, say so or don't suggest it.
- If a concern can't be verified from the code (e.g. it depends on an external service, the deployed environment, a model, hardware or data you cannot see), ask it as a question instead of stating it as a problem.
- If a change could be either a deliberate choice or an oversight (e.g. a changed output or stored format, a removed check, a deviation from how sibling code does it, a case that is silently not handled), first look for the intent in the commit messages, the PR description and comments, code comments and design records. If the intent is documented there, respect it. If not, mark the point as **"Deliberate?"**: state what you noticed, what the consequence would be if it is an oversight, and what would change. Don't present it as a defect.
- Don't supply rationale for a decision yourself. If a document records a decision without its reason, the finding is that the reason is missing, not a guess at it.

## Questions to answer

1. Is the code clean and easy to read?
2. Does the design make sense, and does it respect the boundaries and recorded decisions of the repository?
3. Is it efficient in its execution?
4. Is it the cheapest way, in terms of code additions, to achieve the goal?
5. Is the documentation (comments, docstrings, READMEs, design records, commit/PR text) concise, correct and useful, not bloated with LLM prose, and written for a reader of the file rather than for the conversation that produced it?
6. Does it use the modern idioms of the language version the repository targets, and follow the repository's conventions (naming, layout, placement, public vs. private elements)?
7. Is it compatible with what already exists: public interfaces, stored data, formats, configuration, migrations, cached or hashed results? Is every change to them intended and handled?
8. Is it secure: is every access to protected data authorized, is input from outside validated where it enters, and do secrets stay out of code, logs and config?
9. Is it properly integrated into the rest of the codebase, i.e. does it reuse existing helpers, fixtures and patterns, combine easily with existing features, and update every place that has to agree with it?
10. Is it tested where practical, in the way the changed code's existing tests are set up, and is every test failable, non-vacuous and written against behavior rather than implementation?

Skip question 8 with "Not applicable" when the change touches no trust boundary, secret or external input. The repository's reference may make a question more specific; answer the specific form.

## Repository rules to check

First find the repository's own rules and check the changes against them: `CONTRIBUTING.md`, `README.md`, `CLAUDE.md`/`AGENTS.md` (also in the changed subdirectories), the lint and formatter config, the pinned language and tool versions, the CI config (which checks run, which are auto-fixed), and design records (e.g. `docs/adr/`) that the change touches. A written repository rule takes precedence over the general rules below. In addition:

### Structure and dependencies
- New code is placed where the repository puts code of its kind, and follows how its siblings are written.
- Dependencies point the way the repository's layout intends; nothing reaches into another component's internals or private names.
- Code stays local until a second user needs it; a shared abstraction with one user is a cost.
- A dependency manifest and its lockfile change together; a new dependency is justified by what it saves.

### Compatibility
- A change to a public interface, a serialized or stored format, a config schema or a CLI is backward compatible with existing callers and data, or the break is intended, documented and handled (version bump, migration, deprecation path).
- Readers of a new field or value are deployed before writers use it. A migration that has run beyond a developer's machine is never edited; a new one is added.
- A changed default or a changed result for unchanged input is a compatibility change, also when it comes through a shared base class or helper.

### Robustness
- Invariants are validated where data enters; errors are raised, not logged and ignored.
- A failed or interrupted run leaves no output that looks complete; a repeated run is safe.
- No expensive work or I/O at import, construction or startup time unless that is its purpose.
- For concurrency remarks, find which threads or processes actually call what before calling a lock missing or unnecessary.

### Configuration and secrets
- Configuration is explicit and validated; unknown or missing keys fail loudly instead of being silently defaulted, unless the repository decides otherwise.
- Secrets are not committed (except deliberately worthless development ones), logged, or passed where they leak.

### Documentation and history
- No invented rationale; comments address a reader of the file, not the conversation that produced it ("as requested", "now also", rebuttals of objections nobody raised); length follows what a reader needs.
- Branch work is judged by its end state: no "changed to", "no longer", superseded sections kept under a note, or numbering that only made sense in an earlier draft.
- A change that makes a README, a layout description, an API table, a docstring or a design record wrong updates it in the same branch. A recorded decision that changes is superseded by a new record, not rewritten, if the repository keeps such records.

## Tests

A test is worth its maintenance only if a plausible bug makes it fail. Check every new or changed test against these, and every new or changed behavior for a test. Follow how the changed code is already tested; where it has no tests, say whether the change adds logic that a test could reach cheaply rather than demanding a test setup of its own.

- **Failable.** For each test, name a realistic mistake in the code that would make it fail. If there is none, the test is vacuous. Typical forms: an expected value computed by the code under test, a constant copied from the implementation into the assertion, a stub asserted to return what it was set up to return, a test that only checks that an object can be constructed, a test that passes with the code under test removed or stubbed out.
- **Behavior, not implementation.** Tests drive the public interface and assert what a user or caller observes: what a function returns or stores, what an API answers, what a page shows and sends, what a program writes. A test that calls private helpers, asserts an internal call order or intermediate structure, or would need changing for a refactor that leaves behavior alone is a finding, unless that internal is itself the unit's contract.
- **Not brittle.** No assertions on incidental values: styling and layout, configuration defaults, log or error wording that is not the behavior under test, exact floating-point results where a tolerance is meant, or an order nobody specified. Pinned values whose purpose is to detect change (golden files, snapshot or hash references) are the deliberate exception; then unexplained churn in them is the finding.
- **Stubs at the boundary.** Stubs replace what is outside the unit (network, database, file system beyond a temporary directory, clock, external services and devices), not the unit's own parts. Assertions on a stub's calls are fine when the call is the behavior.
- **A fixed bug has a regression test** that fails without the fix. For a commit that says it fixes something, check that one exists.
- **Prove a vacuity claim before reporting it.** Break the code the test is meant to protect (invert a condition, drop a check, return a constant), run the narrowest test command, and restore the code (`git stash` or `git checkout -- <file>`; never leave the change behind). Report what you changed and that the test still passed. If you could not run it, say the claim is unverified.

## How to work

- Read the whole diff, then the existing code it builds on or duplicates: base classes, sibling implementations, helpers it could reuse, the callers of changed code and the readers of changed data.
- Go through every changed function, endpoint, schema, config key and component systematically, not just the most prominent change. For each, consider boundary cases (empty input, a single element, first and last element, missing optional values, absent or unreachable dependencies, sizes that are or aren't multiples of each other) and every combination with the existing parameters and modes of the same unit.
- Consider how the code is driven at runtime: who calls it, when, how often, on what data, on which machine or in which process, in which order components are deployed, and what an interrupted or repeated run leaves behind.
- Check claims against **all** callers and readers before making them: grep the whole repository, including tests, scripts, deployment and CI config; don't assume a single caller.
- Quantify efficiency points where possible (calls, queries, bytes, runtime or memory for a realistic input), and say when the gain is likely negligible.

## Checks

Find the cheap checks the repository has (CI config, `Makefile`, `package.json` scripts, `pyproject.toml`, `noxfile.py`/`tox.ini`, pre-commit config, the contributing guide) and run them when the environment allows it, scoped to the changed files or components where possible: lint, formatter in check mode, type checker, the narrowest relevant tests. Use the tool versions the repository pins. Say which checks ran and which did not (with the error), and whether the changed code was compiled or tested at all locally.

## Output

- A short overall verdict, e.g. "Ready to merge", "Ready after the fixes below" or "Needs design changes".
- Then the questions in order, each answered with "Yes" or with numbered findings. Each finding has a `file:line` reference, its category (bug / security / compatibility / design / efficiency / test / style, any category the repository's reference adds, or **Deliberate?** when intent is unclear), the concrete consequence and a concrete suggestion.
- Nits (rule violations with no effect on behavior or understanding) go in a separate short list at the end; omit the list if there are none.
- State which checks were run and their result.
- End with the few changes that matter most, or state that nothing needs to change.
- When asked for PR comments, write them the way the user posts them:
  - One comment per finding worth the author's time, anchored at the file and line it is about; a point about a missing test goes on the test it concerns. Drop speculative or non-blocking points, and side remarks the author will see anyway, such as merge conflicts.
  - One to three sentences: the finding in one sentence, then a direct ask ("Could you add …?", "Should this be done in this PR or separately?"). Where there are options, ask rather than prescribe.
  - Leave out what the author already knows, such as how their own code works.
  - No narration of the review: no "I merged …", "I checked …", "I haven't confirmed". A tentative cause stays, phrased plainly: "A possible reason is …".
  - No reference to this review's numbering, no LLM filler, and neutral headings ("Open questions", not questions addressed to named people).
  - Context that helps the user judge a comment goes in the reply to the user, not in the comment.
