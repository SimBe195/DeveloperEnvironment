---
name: bitbucket
description: "Query the Bitbucket Cloud REST API for this repository: branches, commits, diffs, file contents, and pull requests. Use when asked about Bitbucket, PRs, pull requests, review comments, remote branches, or anything on bitbucket.org that is not available from the local clone."
---

# Bitbucket Cloud API

## Authenticate

The credential is an **Atlassian API token** (from id.atlassian.com), not an app password and not
a repository access token. Bitbucket accepts it as **HTTP Basic auth** with the Atlassian account
**email as the username**:

```bash
curl -s -u "$BITBUCKET_EMAIL:$(cat .bitbucket_api_token)" "$URL"
```

A `Bearer` header does **not** work with this token type — that is what workspace and repository
access tokens use. Sending it as a Bearer yields a bare 401 with no explanation, which is easy to
misread as a bad token.

Use `scripts/bb.sh` rather than hand-rolling curl. It resolves three things for you and takes a
path relative to the repository:

- **Token** — `$BITBUCKET_API_TOKEN_FILE`, else `.bitbucket_api_token` found by walking up from the
  working directory, else `~/.config/bitbucket/token`.
- **Email** — `$BITBUCKET_EMAIL`, else `~/.config/bitbucket/email`.
- **Repo slug** — `$BITBUCKET_SLUG`, else derived from `git remote get-url origin`.

```bash
scripts/bb.sh /refs/branches?pagelen=5
scripts/bb.sh /commits/main?pagelen=3
scripts/bb.sh --abs /2.0/user          # non-repo endpoint
```

**Never echo the token, and never paste it into a command whose output you will show.** Read it
only through `$(cat …)` inside the `-u` argument.

## Know what this token can do

Every response carries the granted scopes in a header — read them there rather than provoking
a 403:

```bash
scripts/bb.sh / -D - -o /dev/null | grep -i x-oauth-scopes
```

For PR review work the useful set is `read:user`, `read:repository`, `read:pullrequest` and, if the
assistant should be able to comment or approve, `write:pullrequest`. Verified working against the
live API with those: repository metadata, `refs/branches`, `commits/{rev}`, `diff/{spec}`,
`src/{rev}/{path}`, `/2.0/user`, and the whole `pullrequests` tree — list, detail, `diff`,
`diffstat`, `comments`, `activity`.

Note what `write:pullrequest` does **not** include: there is no `write:repository`, so the token
cannot push. It *can* comment on, approve, and merge pull requests. Treat every non-GET as a real
change visible to the whole team and confirm with the user before sending it.

Distinguish the failure modes: **401** = wrong auth scheme or bad token; **403** = auth fine,
scope missing (the body names both `required` and `granted`); **404** = path or ref does not
exist — a missing file returns 404, not 403.

## Prefer the local clone

`git log`, `git diff` and `git show` answer most questions faster than the API and without rate
limits. Reach for the API only for what the clone cannot know: PR metadata and review state,
comments, approvals, and branches not yet fetched.

When you do want a remote diff, `{spec}` takes the same revision syntax as git:

```bash
scripts/bb.sh "/diff/some-branch..main"     # note: source..destination
```

## Review a pull request

Find the PR for a branch, then pull what you need:

```bash
scripts/bb.sh "/pullrequests?state=OPEN&pagelen=50"   # .values[] -> id, title, source.branch.name
scripts/bb.sh "/pullrequests/123"                     # title, state, reviewers, participants
scripts/bb.sh "/pullrequests/123/diffstat?pagelen=100"
scripts/bb.sh "/pullrequests/123/diff"                # full unified diff
scripts/bb.sh "/pullrequests/123/comments?pagelen=100"
```

Approval state is not a top-level field: read `participants[]` and filter on `approved`, and
note `reviewers[]` lists who was *asked*, which is a different set.

Some fields are omitted from list responses and must be asked for explicitly, e.g.
`?fields=%2Bvalues.reviewers` (`+values.reviewers`, url-encoded). A field you did not ask for comes
back absent, not empty — do not read that as "no reviewers".

Posting requires `write:pullrequest`, so ask first. `bb.sh` forwards extra arguments to curl:

```bash
scripts/bb.sh /pullrequests/123/comments \
  -X POST -H 'Content-Type: application/json' \
  -d '{"content":{"raw":"..."},"inline":{"path":"lib/foo.py","to":42}}'
```

In `inline`, `to` is a line number in the new file and `from` a line in the old one; omit
`inline` entirely for a general PR comment. A `to` outside the diff hunk is accepted and comes back
with `"outdated": false`, so an inline comment on an unchanged line of a changed file works — read
the response back to confirm.

Approve with `POST /pullrequests/{id}/approve` (`DELETE` to withdraw) and
`POST /pullrequests/{id}/request-changes`.

**The review-state endpoints take no body — send one and they 400.** They carry the verdict in the
URL alone, so `-H 'Content-Type: application/json'` with nothing to go with it is what breaks them:

```bash
scripts/bb.sh /pullrequests/123/request-changes -X POST                                      # 200
scripts/bb.sh /pullrequests/123/request-changes -X POST -H 'Content-Type: application/json'  # 400
```

The 400 body is empty, so `--fail-with-body` prints nothing and `curl: (22)` is all you get — easy
to misread as a missing scope or a stale PR. Call them with no extra headers. To say *why* you are
requesting changes, post a comment separately; there is no field for it here.

## Open a pull request — pass the reviewers and the branch flag yourself

Two things the web UI fills in that `POST /pullrequests` does not. Neither errors, so both are
found later rather than at the time.

**Default reviewers are not applied to a PR created through the API.** You get a perfectly normal
PR that simply nobody was asked to review. Read them and put them in the request body; the list is
readable with `read:repository`:

```bash
scripts/bb.sh "/default-reviewers?pagelen=100"    # .values[] -> display_name, uuid, account_id
```

Query it rather than hardcoding names — it changes without notice. `reviewers[]` takes `uuid`
(braces included) or `account_id`. **Bitbucket rejects a PR whose author is also a reviewer**, and
the token authenticates as its owner, so drop the token owner from the list — them only, and only
because they are the author.

**`close_source_branch` defaults to false**, so an API-created PR leaves its branch behind after
the merge while a UI-created one cleans up. Set it explicitly — unless another PR targets this
branch, in which case deleting it on merge would strand that PR.

```bash
scripts/bb.sh /pullrequests -X POST -H 'Content-Type: application/json' -d @/tmp/pr.json
```

```json
{
  "title": "…",
  "source": {"branch": {"name": "my-branch"}},
  "destination": {"branch": {"name": "main"}},
  "description": "…",
  "reviewers": [{"uuid": "{…}"}, {"uuid": "{…}"}],
  "close_source_branch": true
}
```

Build the body in a file and pass it with `-d @file` — a description long enough to be worth
reading does not survive shell quoting. Afterwards, read the PR back and check `reviewers[]` and
`close_source_branch` are what you meant, rather than trusting the 201.

**Editing a PR later has the mirror-image hazard.** `PUT /pullrequests/{id}` replaces the fields you
send, so a body without `reviewers` can leave the PR with none — silently undoing whoever assigned
them, and likewise resetting `close_source_branch` to false by omission. Read the PR first, carry
those fields through the update, and check them again afterwards.

## Read paginated responses

List endpoints return `{"values": [...], "size": N, "next": "<url>"}`. `pagelen` defaults to 10
and caps at 100. Follow `next` until it is absent; do not assume one page is the whole answer — a
mature repository's `refs/branches` runs to hundreds of entries.

`next` is an absolute URL, so feed it to `bb.sh --abs` (strip the host) or to curl directly rather
than to the repo-relative form.

## Two conventions worth adopting

Neither is enforced by this skill; both have earned their place.

- **Ask before every non-GET.** Comments, approvals, requests for changes, merges and PR edits are
  all visible to the whole team, and an assistant's judgement about whether something is worth
  saying is not a substitute for the user's. Permission for one post is not permission for the next.
- **Sign what the assistant writes.** The token authenticates as its owner, so anything posted
  appears under their name and is indistinguishable from something they typed. Ending each posted
  comment with a signature line — e.g. `— Claude Code` — tells the person on the other end who
  wrote it, which they need in order to weigh the review.
