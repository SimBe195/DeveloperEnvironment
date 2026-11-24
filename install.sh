#!/usr/bin/env bash
# Installs and updates the tools and config links of this repository. Asks only about what is
# missing, outdated or installed differently than this platform's default, then runs the accepted
# actions. See README.md.
set -o pipefail

REPO_DIR=$(cd -P "$(dirname "$0")" && pwd -P)
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/tools.sh
source "$REPO_DIR/lib/tools.sh"
# shellcheck source=lib/configs.sh
source "$REPO_DIR/lib/configs.sh"

[[ $# -eq 0 ]] || die "usage: $0 (takes no arguments)"

export PATH=$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.juliaup/bin:$PATH
if [[ -s $NVM_DIR/nvm.sh ]] && node_bin=$(nvm_run command -v node); then
	PATH=$(dirname "$node_bin"):$PATH
fi
BACKUP_DIR=$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)

detect_platform
echo "Platform: $PLATFORM ($OS, $ARCH). Checking tools and configs..."
plan_tools
plan_configs

if [[ ${#ACTION_CMDS[@]} -eq 0 ]]; then
	echo "Nothing to do."
	exit 0
fi
run_actions
