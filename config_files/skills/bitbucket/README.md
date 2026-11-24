# Bitbucket Cloud skill for Claude Code

Lets Claude answer questions about your Bitbucket Cloud repository that the local clone cannot —
pull request metadata, review state, comments, approvals — and, if you grant the scope, post
review comments and approvals on your behalf.

`SKILL.md` is the instruction file Claude reads. `scripts/bb.sh` is a thin curl wrapper that
handles auth and URL construction. Most of the value is in the parts of the Bitbucket API that
behave unexpectedly; those are written down in `SKILL.md` with the reason, so Claude does not have
to rediscover them.

## 1. Install

Copy the `bitbucket/` directory into one of:

```
<your-repo>/.claude/skills/bitbucket/     # this project only, shareable via git
~/.claude/skills/bitbucket/               # all your projects
```

`.claude/skills/` is the path Claude Code discovers automatically. If you keep skills somewhere
else, the file still works as documentation, but you have to point at it — e.g. a line in
`CLAUDE.md` saying "use the bitbucket skill in `<path>`" — or Claude will not know it exists.

Check it is picked up with `/skills` in Claude Code; `bitbucket` should be listed.

## 2. Create an API token

An **Atlassian API token**, not an app password and not a repository/workspace access token — the
auth scheme differs and the others will not work with this script.

1. Go to <https://id.atlassian.com/manage-profile/security/api-tokens>.
2. Create a token **with scopes** (the plain "create API token" button makes an unscoped one).
3. Select at least:
   - `read:user` — resolve accounts and your own identity
   - `read:repository` — branches, commits, diffs, file contents, default reviewers
   - `read:pullrequest` — PRs, comments, activity, approvals
   - `write:pullrequest` — **only if** you want Claude able to comment, approve, or merge PRs.
     Leave it out for a strictly read-only setup.

There is no `write:repository` in that list, so the token cannot push code. It can still merge a
pull request if you grant `write:pullrequest` — that is not a read-only permission.

## 3. Store the token

Anywhere `bb.sh` looks. Pick one:

```bash
# a) per project, at the repo root  -- add it to .gitignore, or keep it one level above the repo
printf '%s' '<token>' > .bitbucket_api_token
chmod 600 .bitbucket_api_token

# b) per user
mkdir -p ~/.config/bitbucket && chmod 700 ~/.config/bitbucket
printf '%s' '<token>' > ~/.config/bitbucket/token
chmod 600 ~/.config/bitbucket/token

# c) explicitly
export BITBUCKET_API_TOKEN_FILE=/secure/path/token
```

**If you use (a), make sure it is gitignored before you commit anything.** A token in a repo is a
token in everyone's clone and in the reflog.

Then the account email, used as the HTTP Basic username:

```bash
printf '%s' 'you@example.com' > ~/.config/bitbucket/email   # or export BITBUCKET_EMAIL
```

The repository is derived from `git remote get-url origin`. Override with
`export BITBUCKET_SLUG=workspace/repo` if the remote is not Bitbucket, or if you want to query a
different repository than the one you are standing in.

## 4. Check it works

```bash
scripts/bb.sh --abs /2.0/user | head -c 200            # who am I
scripts/bb.sh / | head -c 200                          # repository metadata
scripts/bb.sh / -D - -o /dev/null | grep -i x-oauth-scopes   # what the token may do
```

Reading the scopes back is the fastest way to catch a token created without them — the usual
symptom otherwise is a 403 on the first PR call, which reads like the wrong endpoint.

If `/2.0/user` returns 401, the token is being sent the wrong way or is wrong; if it succeeds and a
PR call returns 403, the token is fine and a scope is missing. The 403 body names both the required
and the granted scopes.

## Notes

- `bb.sh` never prints the token; it is read inside the `-u` argument. Keep it that way if you edit
  the script, and do not add a debug `echo` of the curl line.
- The wrapper passes extra arguments through to curl, so `-X POST`, `-d @file`, `-D -` all work.
- Paths are repository-relative by default (`/pullrequests/123`); use `--abs` for endpoints outside
  the repository tree (`--abs /2.0/user`).
- `SKILL.md` recommends asking the user before any non-GET request, and signing comments the
  assistant writes. Both matter because the token authenticates as *you*: anything posted appears
  under your name.

## What is not included

No credentials, no workspace-specific configuration, and no organisation's team member names — the
skill queries `/default-reviewers` at run time instead of carrying a list. Adapt `SKILL.md` freely;
it is written to be read by Claude, and project-specific conventions are worth adding to it.
