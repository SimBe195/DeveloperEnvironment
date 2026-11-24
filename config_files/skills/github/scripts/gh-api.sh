#!/usr/bin/env bash
# Query the GitHub REST API with a personal access token or the gh CLI.
#
#   gh-api.sh /pulls?state=open&per_page=5   -> /repos/<owner>/<repo>/pulls?state=open&per_page=5
#   gh-api.sh --abs /user                    -> /user
#
# Prefers `gh api` when the gh CLI is installed and authenticated, falling back to curl
# with a PAT. The token is read straight into the -H argument and never printed.
set -euo pipefail

die() { echo "gh-api.sh: $*" >&2; exit 2; }

# --- repository slug (owner/repo) --------------------------------------------------------
# $GITHUB_SLUG, else derived from the origin remote. Handles:
#   git@github.com:owner/repo.git
#   https://github.com/owner/repo.git
resolve_slug() {
    if [[ -n "${GITHUB_SLUG:-}" ]]; then
        printf '%s' "$GITHUB_SLUG"
        return
    fi
    local url slug
    url="$(git remote get-url origin 2>/dev/null || true)"
    [[ -n "$url" ]] || die "not in a git repo with an 'origin' remote. Set \$GITHUB_SLUG=owner/repo."
    [[ "$url" == *github.com* ]] \
        || die "origin is not a github.com remote ($url). Set \$GITHUB_SLUG=owner/repo."
    slug="$(printf '%s' "$url" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
    [[ "$slug" == */* ]] \
        || die "could not derive the repo from origin ($url). Set \$GITHUB_SLUG=owner/repo."
    printf '%s' "$slug"
}

# --- token file ---------------------------------------------------------------------------
# $GITHUB_TOKEN, else $GITHUB_API_TOKEN_FILE, else .github_api_token walking up from $PWD,
# else ~/.config/github/token. Ignored when using gh CLI.
resolve_token() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        printf '%s' "$GITHUB_TOKEN"
        return
    fi
    local file=""
    if [[ -n "${GITHUB_API_TOKEN_FILE:-}" ]]; then
        [[ -f "$GITHUB_API_TOKEN_FILE" ]] \
            || die "\$GITHUB_API_TOKEN_FILE is set but $GITHUB_API_TOKEN_FILE does not exist"
        file="$GITHUB_API_TOKEN_FILE"
    else
        local dir="$PWD"
        while [[ "$dir" != / ]]; do
            if [[ -f "$dir/.github_api_token" ]]; then
                file="$dir/.github_api_token"
                break
            fi
            dir="$(dirname "$dir")"
        done
        if [[ -z "$file" ]]; then
            local f="${XDG_CONFIG_HOME:-$HOME/.config}/github/token"
            [[ -f "$f" ]] && file="$f"
        fi
    fi
    [[ -n "$file" ]] || die "no API token found. Set \$GITHUB_TOKEN, put it in .github_api_token at your project root,
     or in ~/.config/github/token, or install and authenticate the gh CLI (gh auth login).
     Create a token at https://github.com/settings/tokens."
    tr -d '\r\n' < "$file"
}

# --- mode: gh CLI or curl -----------------------------------------------------------------
USE_GH=0
if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    USE_GH=1
fi

ABS=0
if [[ "${1:-}" == "--abs" ]]; then
    ABS=1
    shift
fi
[[ $# -ge 1 ]] || die "usage: gh-api.sh [--abs] <path> [curl args...]"

PATH_ARG="$1"
shift

if [[ $USE_GH -eq 1 ]]; then
    # gh api handles auth, pagination headers, and base URL
    if [[ $ABS -eq 1 ]]; then
        exec gh api "$PATH_ARG" "$@"
    else
        exec gh api "repos/$(resolve_slug)${PATH_ARG}" "$@"
    fi
else
    # curl fallback
    TOKEN="$(resolve_token)"
    if [[ $ABS -eq 1 ]]; then
        URL="https://api.github.com${PATH_ARG}"
    else
        URL="https://api.github.com/repos/$(resolve_slug)${PATH_ARG}"
    fi
    curl -sSL --fail-with-body \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$URL" "$@"
fi
