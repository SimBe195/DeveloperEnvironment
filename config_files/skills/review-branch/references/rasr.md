# RASR (C++)

Rules for reviewing a branch of the RASR repository, in addition to `SKILL.md`.

## Findings

- **Bug:** includes a configuration or model whose results change or break, and processing that goes wrong only at a segment start or end.
- **Compatibility:** includes a changed result for an existing configuration (a changed parameter default, a renamed or removed parameter, changed behavior of an existing class through a shared base class).
- **Style:** checked against `CONTRIBUTING.md`, `src/.clang-format` and the style rules below.
- When it can't be verified from the code whether a concern holds (e.g. it depends on the model or runtime behavior), ask it as a question.

## Questions

- **6.** Does it use modern C++ style and follow RASR style patterns (naming, `Core::Component`/`Core::Parameter` usage, header layout, smart pointers instead of `Core::Ref`, `verify` for internal invariants, `Core::Status` instead of `error()`/`criticalError()`/`require`)?
- **7.** Do existing configurations keep their results, or is every change intended and handled?
- **9.** Does it reuse existing functionality of the RASR codebase and combine easily with existing classes?

## Style rules to check

- Read `CONTRIBUTING.md` in the repository root and check the changes against it (naming, include guards, no exceptions, closing-brace comments on long blocks, etc.). Formatting is defined by `src/.clang-format`.
- Include order, each group separated by a blank line:
  1. the file's own header (`"X.hh"` in `X.cc`)
  2. standard library (`<vector>`, `<algorithm>`, …)
  3. third-party (`<cuda_runtime.h>`, `<onnxruntime_cxx_api.h>`, …)
  4. other RASR modules, with angle brackets (`<Core/Application.hh>`)
  5. the same RASR module, with quotes (`"Session.hh"`)

  clang-format only sorts within blocks (`IncludeBlocks: Preserve`), so the grouping and the `<>`/`""` choice must be checked by hand. Flag unused includes.
- Definitions in the `.cc` appear in the same order as the declarations in the `.hh` (classes, members, free functions).
- **Ownership:** new code uses `std::unique_ptr` / `std::shared_ptr` instead of `Core::Ref`. `Core::Ref` is still widespread, but RASR is moving away from it. Don't flag `Core::Ref` where an existing interface the change uses requires it.
- **Error handling:** new code returns a `Core::Status` (`src/Core/Status.hh`) for failures instead of ending the program. The caller can then handle the error, so a RASR server or job in production does not crash. Flag new uses of what ends the program in a standard build:
  - `error()` and `criticalError()`;
  - `require` (including the `_eq`/`_lt`/… forms) and `hope`, which can fail on invalid input or other runtime conditions.

  `verify`, `ensure` and `defect()` are fine for conditions that only a bug in RASR can violate; they document invariants for the reader. Flag them where invalid input, configuration or a runtime event can trigger them. All of these macros call `abort()` in every CMake build type, because the `SPRINT_RELEASE_BUILD` flag that would compile them out is no longer defined; only `require_`, `verify_` and `ensure_` are debug-only.

## Tests

- Tests drive a class through its public interface and check outputs for given inputs and parameters, including at segment boundaries. A test that reaches into private members or checks intermediate buffers is a finding.
- Parameter defaults are incidental values; don't assert them.
- Stubs replace files, external libraries and devices, not the class's own parts.
- To prove a vacuity claim, run the narrowest test the local build provides.

## How to work

- Boundary cases include segment start and end, and sizes that are or aren't multiples of each other (e.g. batch or chunk sizes).
- Consider whether processing is triggered incrementally per input or only at the end, not only the order the code reads in.
- Note whether the changed code was compiled or tested in the local build (e.g. a module flag that is off) and say so.
