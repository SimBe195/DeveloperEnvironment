# AppTalk

Rules for reviewing a branch of the AppTalk repository, in addition to `SKILL.md`.

## Scope

If no base branch is given and there is no Bitbucket PR for the current branch, use `main`. PRs here are often stacked, so the destination is not always `main`.

Ignore `graphify-out/graph.json` in the diff (see "Checks" for whether it is current).

## Findings

- **Bug:** includes a document or a sequence of user actions that produces wrong results.
- **Security** examples: a caller who reaches another organization's data, a role they lack, or a grant for a version they may not run; a secret that reaches a log, an environment variable, a config key or the browser.
- **Compatibility** examples: a contract change `buf breaking` would reject or that a lagging reader cannot parse, a stored document a reader would refuse, a migration that is not backward compatible with the readers currently deployed, an edit to a migration that has run anywhere beyond a developer's machine, a config document a service would refuse at startup. Name the reader, row or environment affected.
- **Design** examples: a service reaching a store or another service it is not an edge of in the architecture, a rule duplicated between backend and SPA that must be kept in sync by hand, code moved to `libs/` with a single consumer.
- **Efficiency** examples, for a realistic organization size: a query that cannot use an index on a table that grows with traffic, one request per card or row where one request would do, a large dependency pulled into the main SPA bundle.
- **Style:** checked against `CONTRIBUTING.md`, `CLAUDE.md`, the lint config and the rules below.
- Documented limitations are the "Not here yet" sections of the service READMEs. What an entry rests on can stop holding: an entry such as "no controls for X; a version keeps whatever X it has" assumes that leaving X unset is valid; if a contract change has since made it undefined, the entry is a finding.
- Earlier decisions include the ADRs.
- When verifying, grep the other services, the SPA, tests, charts and `dev/`. A suggested fix must not break the buf gate or need a migration a deployed reader cannot follow. Concerns that depend on a provider's behavior, the deployed environment or data in a live store are questions.
- Missing rationale is a finding under `CLAUDE.md`, "Do not invent rationale".

## Questions

- **2.** Does it respect the service boundaries and the ADRs?
- **3.** Queries, requests per page, bundle size, work per session.
- **6.** Does it use modern Python (3.13) and TypeScript/React, and follow the AppTalk conventions (`CONTRIBUTING.md`, the per-service contract, placement in the repository)?
- **7.** Is it compatible with what is deployed and stored: contracts, stored documents, migrations, config documents?
- **8.** Is every organization-scoped request authorized, and do secrets stay files?
- **9.** Does it update every place that has to agree with it (charts, `dev/` documents, READMEs, the SPA)?
- **10.** Tested at the level the service's README describes for its tests.

## AppTalk rules to check

Read `CONTRIBUTING.md` and `CLAUDE.md` in the repository root and check the changes against them. When the change touches more than one service, the repo layout, contracts, deployment or datastores, read the ADR index in `docs/adr/README.md` and the ADRs that apply. In particular:

### Services and placement
- Every `services/<name>/` keeps the per-service contract: `README.md`, a `Makefile` with `build`, `test`, `lint` and `image`, a `Dockerfile` whose ignore file follows the build context (`Dockerfile.dockerignore` when the context is the repository root), `src/`, `tests/`.
- Each service locks its own dependencies in its own directory (ADR-0005); a manifest and its lockfile change together.
- Code stays service-local until a second service needs it; only then does it move into `libs/`.
- Anything crossing a service boundary is defined in `contracts/`. A service reads only the stores the architecture gives it (`services/README.md#databases`, ADR-0002).
- An HTTP service listens on 8080 and a gRPC service on 10000 inside its container. On the developer's host, two services run side by side must not claim the same port.

### Contracts and stored documents
- `contracts/` passes `buf lint` (STANDARD: enum value prefixes, `_UNSPECIFIED` zero values, versioned packages) and `buf breaking` against `main` at WIRE_JSON. Within a version, changes are additive; a field or value removed has its number and name reserved.
- A message that versions itself as an envelope (a oneof with one member per shape, such as `AgentPipecatDefinition`) gets a new member for a change that stored data could not be read under, never an edit to an existing member.
- A stored document is parsed with unknown fields rejected by its writer, so every reader must know a new field or value before any writer uses it: readers deploy first.
- Stored JSON uses the field names as declared in the `.proto` (snake_case). Check `contracts/README.md`, "The stored JSON form", for what else is settled and what is still open; don't treat an open point as decided.
- Generated contract code is never committed and never hand-edited (ADR-0011). A `.proto` change is regenerated by each consumer's build.

### Databases and migrations
- The service that writes a store owns its schema and its `migrations/`; readers get `SELECT` only and depend on a published contract or view, never on table layout.
- Every store has its own full connection (host, port, database, user, password), never a shared host plus database names.
- A migration is backward compatible with the readers currently deployed (additive; drop a column a release after the last reader stopped using it). `CREATE DATABASE`, `CREATE ROLE` and reader grants are provisioning (`dev/charts/datastores/files/`), not migrations, except `GRANT SELECT` on a view, which belongs in the migration that creates the view.
- A migration that has run anywhere beyond a developer's machine is never edited; add another (ADR-0008). The frontend's SQL is hand-written, with no ORM.

### Configuration and secrets
- A service reads one complete config document per environment, named by an environment variable: no default path, no overrides, no config in the image (ADR-0018). A config change updates the model, `dev/config/<service>.yaml` and `dev/values/<service>.yaml` together, and the service's tests load every committed document.
- Config models are pydantic, `frozen=True`, `extra="forbid"`, no defaults (ADR-0016).
- A secret is a file at a path, never an environment variable, a config key or a log line (ADR-0014). Development secrets that are committed are worthless by design; real provider keys are never committed.

### Authorization (frontend and gateways)
- Every endpoint under an organization checks membership, or the admin role where it changes the organization, before it reads or writes. Check that a resource looked up by its own id (an agent, a version, a conversation) is also checked to belong to that organization.
- Sign-in, registration and password reset do not reveal whether an account exists, by their answer or by how long they take.
- Nothing unsafe is silently functional: a flow whose delivery is missing (e.g. email) is still gated on its token.

### The SPA (`services/frontend/ui`)
- Formatting and lint are prettier and oxlint, run by `make lint`; types pass `tsc -b`.
- Node is pinned in `.nvmrc`. A suite failing wholesale at `localStorage` means the wrong Node, not a regression.
- Where the API serves a rule the form needs (as `GET /api/agent-options` serves the schema's choices and restrictions), the SPA reads it rather than keeping its own copy.
- Tests stub `fetch` per route through `testSupport.tsx`; a request the test does not serve fails the test, so a new request on a page needs a route in every suite that renders that page, or must fail quietly.

### Documentation and history
- `CLAUDE.md` applies to every document, including code comments, READMEs, ADRs, commit messages and PR descriptions.
- An ADR whose reasoning is not yet recorded is **Proposed**, with a note naming what is missing. A committed ADR is never rewritten: a changed decision gets a new ADR that supersedes it, and an answered open question goes in an `## Updates` section (`docs/adr/README.md`).
- A change that makes the tree in `README.md` or a service README's layout, API table or "Not here yet" section wrong updates it in the same branch.
- Markdown is hand-wrapped at 100 columns (a preference; tables, code blocks and long links exempt); Python is 120, enforced by ruff.

## Tests

- Observable behavior here is the status and body an endpoint answers, the rows a store returns, what a page shows (by role, label or visible text) and what it sends.
- DOM structure the user does not perceive is incidental, like styling; a test that a header's height or a label's punctuation can break is a finding.
- Stubs replace `fetch`, a store and the clock. Assertions on a stub's calls are fine for what reaches the store and what the SPA sends.

## How to work

- Read the sibling endpoints and stores, the SPA pages that call a changed endpoint, the other services that read a changed contract or store, and the charts and `dev/` documents that configure a changed service.
- Go through every changed endpoint, store method, migration, contract message, config key and SPA component. Boundary cases include no rows, a deleted version, a draft vs. a deployed version, a user in two organizations, a member vs. an admin, an absent optional field, an enum left UNSPECIFIED, and a store that is unreachable.
- Consider which service and which version of it reads what, in which order services are deployed, and what a browser does on reload, back navigation or a second tab.
- Grep `services/`, `contracts/`, `deploy/`, `dev/` and the SPA's `src/`. `graphify query "<question>"` finds callers and readers faster than grep; see `CLAUDE.md`, "graphify".
- Quantify efficiency as rows scanned, requests per page load or kB added to the main chunk.

## Checks

- per changed service: `make lint` and `make test` in `services/<name>/`. For the frontend, activate the Node version in `.nvmrc` first (`nvm use <version>`), or the SPA suite fails for reasons unrelated to the change.
- store tests that need a live database run only when their variable names one (e.g. `APPTALK_TEST_LOG_STORE` for the frontend's Log Store tests); say whether they ran.
- for a change under `contracts/`: `ci/check-contracts.sh` if `buf` is available, else say that the buf gate was not run.
- for changed Markdown: `tools/reflow-markdown.py --check <changed .md files>`.
- whether `graphify-out/graph.json` is current: only on a clean working tree, and with the graphify version pinned in `bitbucket-pipelines.yml`, run `PYTHONHASHSEED=0 graphify update . && tools/canonicalize-graph.py graphify-out/graph.json`, report whether the file changed, and restore it (`git checkout -- graphify-out/graph.json`). A stale graph is a nit: CI rebuilds it but fails the build when it has to.
