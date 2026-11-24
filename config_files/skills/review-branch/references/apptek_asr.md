# apptek_asr

Rules for reviewing a branch of the apptek_asr repository, in addition to `SKILL.md`.

## Scope

If no base branch is given and there is no Bitbucket PR for the current branch, use `main`.

## Findings

- **Hash** (an additional category): a change of existing job hashes (reruns of finished work, broken reference hashes) or of the value an existing artefact builds, that is not intended. Name the affected job, setup or artefact.
- **Design** examples: a combination with an existing job, factory or meta class that breaks; a reusable existing helper or job (in `apptek_asr` or `i6_core`) that was ignored.
- **Efficiency** examples: requirements far off the actual need, work done at graph construction time, a job that rereads a large corpus per segment.
- **Style:** checked against `contributing.md`, the ruff config in `pyproject.toml` and the rules below; artefact descriptions count as documentation.
- CI's lint step fixes and commits ruff formatting and fixable lint, import sorting, and missing or misordered `__all__` entries; don't report those. Wrongly public elements (missing `_` prefix) are not auto-fixed and are in scope.
- Code under `users/` is personal: only flag real bugs there, and imports of `users/` from outside it.
- When verifying, grep the setups, meta classes, artefact factories and tests. A suggested fix must not change hashes of existing setups or the value of an existing artefact unless that is said. Concerns that depend on the model, the cluster or data on `/nas`/S3 are questions.
- A hash or artefact value change, or a deviation from how sibling jobs or factories do it, without documented intent is a **Deliberate?** point.

## Questions

- **3.** Is it efficient both at graph construction time and when the jobs run?
- **5.** Include artefact descriptions.
- **6.** Does it use modern Python (3.12) and follow the apptek_asr conventions (`contributing.md`, job layout, `__all__`, placement in the repository)?
- **7.** Are existing job hashes and artefact values preserved, or is every change to them intended and handled?
- **9.** Does it reuse existing jobs, meta classes, factories and helpers (here and in `i6_core`) and combine easily with them?
- **10.** New or changed jobs and factories have focused tests under `test/`, mirroring the source path.

## apptek_asr rules to check

Read `contributing.md` in the repository root and check the changes against it. In particular:

### Placement and imports
- Sisyphus jobs live in the topical top-level directory (not `lib/`), names end in `Job`. Meta classes that use jobs go into `meta/` and don't inherit from `Job`. Other helper code goes into `lib/`. Artefact-producing setups go into `setups/` (path mirroring `/nas/models/asr/artefacts`), everything else into `users/`.
- Nothing outside `users/` imports from `apptek_asr.users`; artefacts are imported from `apptek_asr.artefacts`, not `apptek_asr.artefacts.factory` (both are banned in `pyproject.toml`).

### Public/private elements
- Each module has `__all__` at the top listing every public name, in definition order (CI runs `test/public_elements/check_public_elements.py --same_order`). Elements used only within the module are prefixed with `_`, and private names are never imported from other modules.

### Sisyphus jobs
- `__init__` is grouped into blocks separated by blank lines: inputs, outputs, requirements (`self.rqmt`), optionally intermediate variables.
- Inputs that are files are `tk.Path`/`tk.Variable`, not `str`; calling `.get_path()`, `str()` or `.get()` on an input in `__init__` or at graph construction time drops the dependency or reads an unfinished output.
- No expensive work or file I/O at graph construction time (`__init__`, meta classes, factory constructors): it runs on every config load and in the hash check.
- `run()` writes intermediate results in the work dir and moves them into `output/` only when complete, so a failed or interrupted run leaves no valid-looking output. Check `resume` and `mini_task` settings and that the requirements match the realistic workload.
- Errors are raised, not logged and ignored; asserts are fine for internal invariants.

### Hash stability
- A new `__init__` parameter of an existing job changes the hash of every existing usage unless its default is listed in `__sis_hash_exclude__` (or the job's `hash()` override drops it). Check every changed job signature this way, and check that the excluded default really reproduces the old behavior.
- Renaming or moving a job class or module, changing the type of an argument (e.g. `str` → `tk.Path`, list → tuple), or changing defaults also changes hashes.
- Changing the behavior of `run()` without a hash change means finished jobs keep their old output while new ones differ: flag it as **Deliberate?** when the outputs differ.
- If the branch touches `test/hash_test/reference_hashes/` or `test/hash_test/exemption_list.txt`, every changed reference hash must be explained by an intended change; unexplained churn is a finding. Conversely, a new setup config under `setups/**/config/` needs a reference hash file (or an exemption, or the `tuning_` prefix).

### Artefacts
- Follow `.agents/skills/artefact-repository/references/adding.md` ("Protect existing artefacts", "Keep construction light and builds independent", "Preserve history and provenance", "Respect namespace restrictions", "Preserve repository invariants"). Key points: the value an existing artefact builds is a compatibility contract (also through shared base classes and defaults); constructors are light and `build()` is idempotent and returns fresh mutable objects; replaced artefacts are deprecated with a `replacement`; `created_by_config` points to the producing setup; descriptions are useful; no additions to deprecated namespaces.
- Sampling-rate namespaces use the `f8kHz`/`f16kHz`/`f8kHz_as_16kHz`/`mbw` convention. Names and namespaces of `prod` and `test_set` artefacts are anonymized (no customer names).
- For production models, check that companion changes are present where recent history shows them (e.g. `meta/prod_models.py`, deployment tests, manifests).

## Tests

- A job is tested by what its tasks write to its outputs for a small input; a factory or meta class by what it builds; a helper by what it returns. A test that only checks that a job or factory can be constructed is vacuous.
- Requirement numbers are incidental values; don't assert them. The reference hashes under `test/hash_test/` are the deliberate exception: pinning hashes is their purpose.
- Stubs replace the file system beyond a temporary directory, the cluster, S3 and `/nas`.
- To prove a vacuity claim, run the narrowest `pytest test/...`.

## How to work

- Read the base jobs, sibling jobs and factories, meta classes, `i6_core` equivalents, and the setups that use the changed code.
- Boundary cases include empty corpus or file lists, a single segment, missing optional inputs, 8 kHz vs 16 kHz vs mbw, and `None` defaults.
- Consider what runs at graph construction time vs. in the job's tasks, on which machine (cluster node, CI, autoeval), and with which paths available (`/nas`, S3).
- Grep for every usage in `setups/`, `meta/`, `artefacts/` and `test/`, and note usages in `users/`, which may break silently.

## Checks

- `ruff check <changed files>` and `ruff format --diff <changed files>`
- `python3 test/public_elements/check_public_elements.py --same_order`
- the narrowest relevant `pytest test/...` (CI excludes the `development`, `apptek_cluster`, `have_s3_access` and `autoeval_cluster` markers)
- for changed jobs or setups, the hash check of the affected configs: `nox -p 3.12 --sessions check_hashes -- --filter '<regex>'` (needs `i6_core` next to the repository on `PYTHONPATH`, as in `bitbucket-pipelines.yml`)
