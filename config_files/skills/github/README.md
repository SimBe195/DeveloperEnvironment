# GitHub skill for Claude Code

Lets Claude answer questions about your GitHub repository that the local clone cannot —
pull request metadata, review state, comments, check runs, approvals — and, if you grant the
scope, post review comments and approvals on your behalf.

`SKILL.md` is the instruction file Claude reads. `scripts/gh-api.sh` is a thin wrapper that
prefers the `gh` CLI when available and falls back to curl with a PAT. Most of the value is in
the GitHub API quirks documented in `SKILL.md` so Claude does not have to rediscover them.

## 1. Install

Copy the `github/` directory into one of:

```
<your-repo>/.claude/skills/github/     # this project only, shareable via git
~/.claude/skills/github/               # all your projects
```

`.claude/skills/` is the path Claude Code discovers automatically. Check it is picked up with
`/skills` in Claude Code; `github` should be listed.

## 2. Authenticate

### Option A: gh CLI (recommended)

If you already have the [GitHub CLI](https://cli.github.com/) installed and authenticated:

```bash
gh auth status   # confirm you are logged in
```

That's it — `gh-api.sh` detects it and routes all calls through `gh api`, which handles auth
automatically.

### Option B: Personal access token

Create a **fine-grained personal access token** (preferred) or a classic token.

1. Go to <https://github.com/settings/tokens?type=beta> (fine-grained) or
   <https://github.com/settings/tokens> (classic).
2. For fine-grained tokens, select the target repository and grant:
   - `Contents: Read` — branches, commits, diffs, file contents
   - `Metadata: Read` — repository metadata (granted by default)
   - `Pull requests: Read` — PRs, comments, reviews
   - `Pull requests: Write` — **only if** you want Claude able to comment, review, or merge PRs
3. For classic tokens, select the `repo` scope (or `public_repo` for public repos only).

## 3. Store the token

Anywhere `gh-api.sh` looks. Pick one:

```bash
# a) Environment variable (e.g. in your shell profile)
export GITHUB_TOKEN='ghp_...'

# b) Per project, at the repo root — add it to .gitignore
printf '%s' 'ghp_...' > .github_api_token
chmod 600 .github_api_token

# c) Per user
mkdir -p ~/.config/github && chmod 700 ~/.config/github
printf '%s' 'ghp_...' > ~/.config/github/token
chmod 600 ~/.config/github/token

# d) Explicitly
export GITHUB_API_TOKEN_FILE=/secure/path/token
```

**If you use (b), make sure it is gitignored before you commit anything.**

The repository is derived from `git remote get-url origin`. Override with
`export GITHUB_SLUG=owner/repo` if the remote is not GitHub, or if you want to query a
different repository.

## 4. Check it works

```bash
# With gh CLI
gh api repos/:owner/:repo --jq .full_name

# With the wrapper script
scripts/gh-api.sh / | head -c 200                # repository metadata
scripts/gh-api.sh --abs /user | head -c 200      # who am I
scripts/gh-api.sh --abs /rate_limit               # rate limit budget
```

## Notes

- `gh-api.sh` never prints the token; it is read inside the header argument. Keep it that way if
  you edit the script.
- The wrapper passes extra arguments through to `gh api` or curl.
- Paths are repository-relative by default (`/pulls/123`); use `--abs` for endpoints outside
  the repository tree (`--abs /user`).
- `SKILL.md` recommends asking the user before any non-GET request, and signing comments the
  assistant writes. Both matter because the token authenticates as *you*: anything posted appears
  under your name.

## What is not included

No credentials, no org-specific configuration, and no hardcoded usernames. Adapt `SKILL.md`
freely; it is written to be read by Claude, and project-specific conventions are worth adding.
