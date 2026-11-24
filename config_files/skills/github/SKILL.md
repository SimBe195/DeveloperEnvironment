---
name: github
description: "Query the GitHub REST API for this repository: branches, commits, diffs, file contents, and pull requests. Use when asked about GitHub, PRs, pull requests, review comments, checks, remote branches, or anything on github.com that is not available from the local clone."
---

# GitHub REST API

## Authenticate

The `gh` CLI is the preferred interface — it handles auth, pagination, and URL construction. If
`gh` is installed and authenticated (`gh auth status`), all calls go through it. Otherwise the
script falls back to curl with a **personal access token (PAT)** sent as a `Bearer` token:

```bash
curl -s -H "Authorization: Bearer $(cat .github_api_token)" "$URL"
```

**Do not use Basic auth** — GitHub deprecated password auth for the API. A PAT must go in the
`Authorization: Bearer` header, not in `-u`.

Use `scripts/gh-api.sh` rather than hand-rolling curl. It resolves three things for you and takes
a path relative to the repository:

- **Auth** — `gh` CLI if available, else `$GITHUB_TOKEN`, else `$GITHUB_API_TOKEN_FILE`, else
  `.github_api_token` found by walking up from the working directory, else
  `~/.config/github/token`.
- **Repo slug** — `$GITHUB_SLUG`, else derived from `git remote get-url origin`.
- **Base URL** — prepends `repos/{owner}/{repo}` for repo-relative paths.

```bash
scripts/gh-api.sh "/branches?per_page=5"
scripts/gh-api.sh "/commits?sha=main&per_page=3"
scripts/gh-api.sh --abs /user                    # non-repo endpoint
```

When the `gh` CLI is in use, extra arguments are passed to `gh api`. When falling back to curl,
extra arguments are passed to curl.

**Never echo the token, and never paste it into a command whose output you will show.** Read it
only through `$(cat …)` inside the header argument.

## Know what this token can do

Check the token's scopes:

```bash
# With curl — the scopes come back in a response header
scripts/gh-api.sh / 2>&1 | head -1   # just confirm 200
curl -sI -H "Authorization: Bearer $(cat ~/.config/github/token)" https://api.github.com \
  | grep -i x-oauth-scopes
```

For PR review work the useful scopes are `repo` (or the fine-grained equivalents:
`contents:read`, `metadata:read`, `pull_requests:read`). To comment or review, you need
`pull_requests:write`. Fine-grained tokens are preferred over classic tokens — they can be scoped
to specific repositories.

Distinguish the failure modes: **401** = bad token or wrong auth scheme; **403** = token valid but
insufficient scope, or rate-limited (check `X-RateLimit-Remaining` header); **404** = resource
does not exist, *or* the token lacks permission to see it (GitHub returns 404 instead of 403 for
private repos to avoid leaking existence).

## Prefer the local clone

`git log`, `git diff` and `git show` answer most questions faster than the API and without rate
limits. Reach for the API only for what the clone cannot know: PR metadata and review state,
comments, approvals, check runs, and branches not yet fetched.

## Prefer the gh CLI for common operations

When `gh` is available, prefer its porcelain commands for common tasks — they handle pagination,
formatting, and edge cases:

```bash
gh pr list --state open --limit 50
gh pr view 123
gh pr diff 123
gh pr checks 123
gh pr view 123 --comments
gh issue list --limit 20
gh issue view 456
```

Fall back to `gh api` or `scripts/gh-api.sh` for anything the porcelain does not cover.

## Review a pull request

Find the PR for a branch, then pull what you need:

```bash
# List open PRs
scripts/gh-api.sh "/pulls?state=open&per_page=50"

# PR detail — title, state, user, requested_reviewers, mergeable, draft
scripts/gh-api.sh "/pulls/123"

# Files changed — filename, status, additions, deletions, patch
scripts/gh-api.sh "/pulls/123/files?per_page=100"

# Full diff as unified diff
scripts/gh-api.sh "/pulls/123" -H "Accept: application/vnd.github.diff"

# Review comments (inline on the diff)
scripts/gh-api.sh "/pulls/123/comments?per_page=100"

# Issue comments (general PR conversation)
scripts/gh-api.sh "/issues/123/comments?per_page=100"

# Reviews (approved, changes_requested, commented)
scripts/gh-api.sh "/pulls/123/reviews?per_page=100"

# Check runs / CI status
scripts/gh-api.sh "/commits/{sha}/check-runs?per_page=100"
# or more conveniently:
gh pr checks 123
```

### Comments live in two places

GitHub has **review comments** (`/pulls/123/comments`) — attached to a diff line — and **issue
comments** (`/issues/123/comments`) — the general conversation thread. They are different API
resources with different schemas. To see the full conversation, read both.

### Review state

Reviews are on `/pulls/123/reviews`. Each review has a `state`: `APPROVED`,
`CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`, or `PENDING`. A user's effective review state is
their **most recent non-dismissed, non-pending review** — there is no shortcut field for this;
you must read the list and take the last one per user.

`requested_reviewers` on the PR object lists who was *asked* to review; `reviews` lists who
*has* reviewed. These are different sets.

### Posting review comments

Posting requires `pull_requests:write` scope, so ask first. Use `gh api` or curl:

```bash
# General PR comment (issue comment)
scripts/gh-api.sh /issues/123/comments \
  -X POST -f body="Your comment here"

# Inline review comment on a specific line
scripts/gh-api.sh /pulls/123/comments \
  -X POST \
  -f body="Comment text" \
  -f commit_id="abc123" \
  -f path="src/foo.py" \
  -f line=42 \
  -f side="RIGHT"
```

For inline comments, `line` is the line number in the **diff hunk**, and `side` is `RIGHT` (new
file) or `LEFT` (old file). You must also provide `commit_id` — use the PR's `head.sha`.

To post a **formal review** (approve / request changes) with optional inline comments:

```bash
scripts/gh-api.sh /pulls/123/reviews \
  -X POST \
  --input /tmp/review.json
```

```json
{
  "event": "APPROVE",
  "body": "Looks good!",
  "comments": [
    {
      "path": "src/foo.py",
      "line": 42,
      "side": "RIGHT",
      "body": "Nit: consider renaming this"
    }
  ]
}
```

`event` is one of `APPROVE`, `REQUEST_CHANGES`, or `COMMENT`. **`REQUEST_CHANGES` requires a
non-empty `body`** — omitting it yields a 422.

## Open a pull request

```bash
gh pr create --title "Title" --body "Description" --base main --head feature-branch
```

Or via the API:

```bash
scripts/gh-api.sh /pulls \
  -X POST \
  -f title="Title" \
  -f body="Description" \
  -f head="feature-branch" \
  -f base="main" \
  -f draft=false
```

### Reviewers are not automatic via the API

Like Bitbucket, **CODEOWNERS and branch protection review requirements are evaluated by GitHub
after creation**, but explicit reviewer requests must be made separately:

```bash
scripts/gh-api.sh /pulls/123/requested_reviewers \
  -X POST \
  -f 'reviewers[]=username1' \
  -f 'reviewers[]=username2' \
  -f 'team_reviewers[]=team-slug'
```

Or use the CLI: `gh pr edit 123 --add-reviewer username1,username2`.

**A user cannot request a review from themselves** — the API returns 422 if you try.

### Labels, assignees, and milestones

These are on the **issue** endpoint, not the PR endpoint:

```bash
scripts/gh-api.sh /issues/123/labels -X POST -f 'labels[]=bug'
scripts/gh-api.sh /issues/123 -X PATCH -f 'assignees[]=username'
```

## Read paginated responses

The GitHub API returns pagination info in the `Link` response header, not in the body. Default
page size is 30, max is 100 (set with `per_page=100`).

With `gh api`, use `--paginate` to automatically follow all pages:

```bash
gh api repos/owner/repo/pulls?state=all&per_page=100 --paginate
```

With curl, parse the `Link` header for `rel="next"`:

```bash
Link: <https://api.github.com/repos/...?page=2>; rel="next", <...?page=5>; rel="last"
```

**`--paginate` with `gh api` concatenates JSON arrays automatically** — it produces valid JSON
with all items, not multiple JSON blobs. But be aware it can fetch a lot of data; always set
`per_page=100` to minimize round trips.

## Rate limits

GitHub enforces rate limits: 5,000 requests/hour for authenticated requests. Check your budget:

```bash
scripts/gh-api.sh --abs /rate_limit
```

The response includes `rate.remaining` and `rate.reset` (Unix timestamp). If you are close to the
limit, batch your questions and prefer the local clone.

**Secondary rate limits** apply to content-creating endpoints — too many POSTs in quick succession
get throttled with a `Retry-After` header. Do not retry in a tight loop; wait the indicated time.

## Two conventions worth adopting

Neither is enforced by this skill; both have earned their place.

- **Ask before every non-GET.** Comments, approvals, requests for changes, merges and PR edits are
  all visible to the whole team, and an assistant's judgement about whether something is worth
  saying is not a substitute for the user's. Permission for one post is not permission for the next.
- **Sign what the assistant writes.** The token authenticates as its owner, so anything posted
  appears under their name and is indistinguishable from something they typed. Ending each posted
  comment with a signature line — e.g. `— Claude Code` — tells the person on the other end who
  wrote it, which they need in order to weigh the review.
