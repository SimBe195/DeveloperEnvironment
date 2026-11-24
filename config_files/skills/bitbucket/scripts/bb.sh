#!/usr/bin/env bash
# Query the Bitbucket Cloud REST API with an Atlassian API token.
#
#   bb.sh /refs/branches?pagelen=5   -> /2.0/repositories/<workspace>/<repo>/refs/branches?pagelen=5
#   bb.sh --abs /2.0/user            -> /2.0/user
#
# Auth is HTTP Basic with the Atlassian account email as the username. The token is read
# straight into the -u argument and never printed.
set -euo pipefail

die() { echo "bb.sh: $*" >&2; exit 2; }

# --- account email ---------------------------------------------------------------------
# $BITBUCKET_EMAIL, else a one-line ~/.config/bitbucket/email, else give up with instructions.
resolve_email() {
    if [[ -n "${BITBUCKET_EMAIL:-}" ]]; then
        printf '%s' "$BITBUCKET_EMAIL"
        return
    fi
    local f="${XDG_CONFIG_HOME:-$HOME/.config}/bitbucket/email"
    if [[ -f "$f" ]]; then
        tr -d '\r\n' < "$f"
        return
    fi
    die "no account email. Set \$BITBUCKET_EMAIL, or write it to $f.
     This is the Atlassian account email, used as the HTTP Basic username."
}

# --- repository slug -------------------------------------------------------------------
# $BITBUCKET_SLUG, else derived from the origin remote. Handles both forms:
#   git@bitbucket.org:workspace/repo.git
#   https://user@bitbucket.org/workspace/repo.git
resolve_slug() {
    if [[ -n "${BITBUCKET_SLUG:-}" ]]; then
        printf '%s' "$BITBUCKET_SLUG"
        return
    fi
    local url slug
    url="$(git remote get-url origin 2>/dev/null || true)"
    [[ -n "$url" ]] || die "not in a git repo with an 'origin' remote. Set \$BITBUCKET_SLUG=workspace/repo."
    [[ "$url" == *bitbucket.org* ]] \
        || die "origin is not a bitbucket.org remote ($url). Set \$BITBUCKET_SLUG=workspace/repo."
    slug="$(printf '%s' "$url" | sed -E 's#^.*bitbucket\.org[:/]##; s#\.git$##')"
    [[ "$slug" == */* ]] \
        || die "could not derive the repo from origin ($url). Set \$BITBUCKET_SLUG=workspace/repo."
    printf '%s' "$slug"
}

# --- token file ------------------------------------------------------------------------
# $BITBUCKET_API_TOKEN_FILE, else .bitbucket_api_token walking up from $PWD, else
# ~/.config/bitbucket/token. Keep it out of the repo, or gitignore it.
resolve_token_file() {
    if [[ -n "${BITBUCKET_API_TOKEN_FILE:-}" ]]; then
        [[ -f "$BITBUCKET_API_TOKEN_FILE" ]] \
            || die "\$BITBUCKET_API_TOKEN_FILE is set but $BITBUCKET_API_TOKEN_FILE does not exist"
        printf '%s' "$BITBUCKET_API_TOKEN_FILE"
        return
    fi
    local dir="$PWD"
    while [[ "$dir" != / ]]; do
        if [[ -f "$dir/.bitbucket_api_token" ]]; then
            printf '%s' "$dir/.bitbucket_api_token"
            return
        fi
        dir="$(dirname "$dir")"
    done
    local f="${XDG_CONFIG_HOME:-$HOME/.config}/bitbucket/token"
    [[ -f "$f" ]] && { printf '%s' "$f"; return; }
    die "no API token found. Put it in .bitbucket_api_token at your project root, or in $f,
     or point \$BITBUCKET_API_TOKEN_FILE at it. Create the token at id.atlassian.com
     (Security -> API tokens); see SKILL.md for the scopes."
}

ABS=0
if [[ "${1:-}" == "--abs" ]]; then
    ABS=1
    shift
fi
[[ $# -ge 1 ]] || die "usage: bb.sh [--abs] <path> [curl args...]"

PATH_ARG="$1"
shift

if [[ $ABS -eq 1 ]]; then
    URL="https://api.bitbucket.org${PATH_ARG}"
else
    URL="https://api.bitbucket.org/2.0/repositories/$(resolve_slug)${PATH_ARG}"
fi

TOKEN_FILE="$(resolve_token_file)"

# -L because /diff and /diffstat 302-redirect to a signed URL; without it they return 0 bytes.
# curl drops the credentials on a cross-host redirect, which is correct -- the target is signed.
# A 403 body names the required and granted scopes -- keep it on stdout, do not swallow it.
curl -sSL --fail-with-body -u "$(resolve_email):$(cat "$TOKEN_FILE")" "$URL" "$@"
