# How I want you to work, in every project

Write code that would pass a thorough review on the first attempt. The rules below are what such a
review checks, turned around into how to write the code.

## Before starting a task

- **Ask for missing information; don't fill it in.** Review the task for what I didn't provide
  (requirements, scope, constraints, expected behavior) and that the code and documentation don't
  answer either. Ask me about each gap instead of choosing an answer yourself.
- **Rate your confidence first.** Before starting, tell me on a scale of 1 to 10 how confident you
  are that you can do the task well, given its difficulty, its scope and the available information.
- **Below 10, discuss before implementing.** Name the information or resources that are missing, or
  how the problem could be broken into smaller steps, and discuss this with me so we can refine the
  plan or I can add context before you start the implementation.

## Before changing code

- **Read what the change builds on**: the code it extends, its siblings, and helpers it could reuse.
  Follow the repository's own conventions (`CONTRIBUTING.md`, the project's `CLAUDE.md`, its lint
  config) over general habits.
- **Find every caller and reader** of what you change before changing it. Don't assume a single
  caller.
- **Respect documented decisions.** Check commit messages, PR comments, code comments and design
  records for why something is the way it is. Don't reverse a decision because an alternative is
  also reasonable; if it looks wrong, say so and ask.

## Writing code

- **The cheapest change that achieves the goal**, in code added. Reuse existing helpers and patterns
  rather than writing new ones; don't duplicate logic that would then have to be kept in sync.
- **No invariant a caller can break without an error.** Validate where data enters, and fail loudly
  rather than logging and carrying on.
- **Think through boundary cases** for every changed function: empty input, a single element,
  missing optional values, the first and last element, and each combination with the existing
  options of the same function or component.
- **Consider how the code runs**, not only how it reads: who calls it, when, how often, on what
  data, and what an interrupted or repeated run leaves behind.
- **Efficiency where it is measurable.** Avoid real costs for realistic inputs, such as repeated
  work, one request or query per item, or loading far more than needed. Don't trade readability for
  a gain that is negligible.
- **Leave unrelated code alone.** Mention a pre-existing problem you notice instead of fixing it in
  passing.

### RASR (C++)

- **Smart pointers, not `Core::Ref`.** `Core::Ref` is still used in many places, but RASR is moving
  away from it. New code uses `std::unique_ptr` or `std::shared_ptr`, unless an existing interface
  requires a `Core::Ref`.
- **Return `Core::Status`, don't crash.** Return a `Core::Status` (`src/Core/Status.hh`) for a
  failure so the caller can handle it and a RASR server or job in production doesn't crash. Don't
  end the program through `error()`, `criticalError()`, `require` or `hope`, which can fail on
  invalid input or other runtime conditions. `verify`, `ensure` and `defect()` are fine for
  conditions only a bug can violate, but they too call `abort()` in every CMake build type, so
  never use them for anything input or configuration can trigger.

## Documentation

- **Concise and useful.** Comments, docstrings, READMEs and commit or PR text say what a reader
  needs and stop. No filler, no restating the code, no LLM prose.
- **Written for the reader of the file**, who has never seen our conversation. No "as requested",
  "now also", "changed to", or defences against objections only the conversation raised.
- **Don't invent reasons.** Record decisions as they were made. If the reason for a choice was not
  stated, say so or ask; don't write a plausible one.
- **Correct.** Update every comment, README or design note that the change makes wrong.

## Checking your work

- **Verify claims before making them.** Trace the failing case through the code, or run it. If
  something can't be checked from the code, ask it as a question rather than stating it.
- **Run the cheap checks** the repository has (its lint, formatter and the narrowest relevant
  tests) and say which ran and which did not, with the error.
- **Report what was done plainly**: what changed, what was verified, what was skipped, and what is
  still open.

## Tests

### Write the test first

- **Test-driven.** Before implementing a behavior, write the tests that describe it and run them to
  see them fail. Then implement until they pass.
- **A bug gets a failing test before its fix.** When you find a bug, first write a test that fails
  because of it, and run it to confirm that it fails for that reason. Then fix the bug and run the
  test again to confirm that it passes. This keeps the same bug from coming back unnoticed.
- If a test passes before the behavior exists or before the fix is applied, it does not test what it
  claims to. Rework it until it fails for the right reason.

### What a good test is

- **Failable.** Each test exists to catch a plausible bug, and you should be able to name that bug.
  If no realistic mistake in the code would make the test fail, the test is useless: delete it or
  rewrite it. When in doubt, break the code on purpose and check that a test fails.
- **Non-vacuous.** No tests that amount to `X == X`: an expected value computed by the code under
  test, a constant copied from the implementation into the assertion, or a mock asserted to return
  what it was told to return.
- **Behavior, from the user's or caller's side.** Test what a user or caller can observe through the
  public interface: what an API answers, what a page shows and sends, what a function returns or
  stores. Do not mirror the implementation (private helpers, internal call order, intermediate
  data structures). A refactor that does not change behavior must not need a test change.
- **Not brittle.** Do not assert incidental values: styling and layout (sizes, colors, CSS classes),
  configuration values, exact wording that is not the behavior being tested, or an order nobody
  specified. Changing the height of a header must not break a test.
- **Stubs at the boundary.** Stub what is outside the unit (network, a database, a clock) rather than
  the unit's own collaborators. Assert on calls to a stub only when those calls are the behavior,
  such as what a request sends.
