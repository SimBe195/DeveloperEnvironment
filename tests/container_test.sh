#!/usr/bin/env bash
# End-to-end test of install.sh on Ubuntu as a user without sudo, i.e. the user-local install path.
# Needs docker and network access. The first install builds several tools with cargo and takes a
# while.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)

docker build -q -t devenv-test - >/dev/null <<'EOF'
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    zsh git curl ca-certificates build-essential \
 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/zsh dev
USER dev
WORKDIR /home/dev
EOF

docker run --rm -i -v "$REPO_DIR:/repo:ro" devenv-test bash -s <<'EOF'
set -uo pipefail
failed=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; failed=1; return 1; fi
}

cp -r /repo ~/DeveloperEnvironment
cd ~/DeveloperEnvironment
export PATH=$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.juliaup/bin:$PATH

yes y | ./install.sh >/tmp/first.log 2>&1
rc=${PIPESTATUS[1]}
check "first run succeeds" "[ $rc -eq 0 ]" || tail -40 /tmp/first.log
for cmd in nv lazygit gdu fzf starship dstask tldr uv juliaup cargo rg bat fd btm tree-sitter claude; do
	check "$cmd is installed" "command -v $cmd >/dev/null"
done
check "nv runs" "nv --version >/dev/null"
check "Node and codex are installed via nvm" \
	"bash -c '. ~/.nvm/nvm.sh && nvm use --silent default && command -v codex' >/dev/null"
check "oh-my-zsh and plugins are installed" \
	"[ -f ~/.oh-my-zsh/oh-my-zsh.sh ] && [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]"
check "tmux missing is reported, not asked" "grep -q tmux /tmp/first.log && ! command -v tmux"
check "zshrc is linked" "[ \"\$(readlink ~/.zshrc)\" = ~/DeveloperEnvironment/config_files/zshrc ]"
check "skills are linked for Claude Code" "[ -f ~/.claude/skills/review-branch/SKILL.md ]"
check "skills are linked for Codex" "[ -f ~/.agents/skills/review-branch/SKILL.md ]"
check "Codex reads CLAUDE.md" "cmp -s ~/.codex/AGENTS.md config_files/CLAUDE.md"
check "nvim config is cloned" "[ -d ~/.config/nvim/.git ]"
check "zsh starts without errors" "[ -z \"\$(zsh -i -c true 2>&1 | grep -v 'zle')\" ]" ||
	zsh -i -c true 2>&1 | grep -v zle

# A run with nothing to do must not ask anything: with stdin closed, any question fails the run.
./install.sh </dev/null >/tmp/second.log 2>&1
rc=$?
check "second run asks nothing" "[ $rc -eq 0 ]" || tail -20 /tmp/second.log

# An outdated tool is the only thing offered, and gets updated.
curl -fsSL https://github.com/junegunn/fzf/releases/download/v0.60.0/fzf-0.60.0-linux_amd64.tar.gz \
	| tar xz -C ~/bin fzf
printf 'y\n' | ./install.sh >/tmp/third.log 2>&1
rc=$?
check "outdated fzf is the only question" "[ $rc -eq 0 ]" || tail -20 /tmp/third.log
check "fzf is updated" "! fzf --version | grep -q '^0.60.0'"

exit $failed
EOF
