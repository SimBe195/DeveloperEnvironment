# shellcheck shell=bash
# Config links for install.sh. A config is only offered when its tool is installed or about to be,
# and only when its links are not already in place. Files a link would replace are moved to
# $BACKUP_DIR.

NVIM_CONFIG_URL=https://github.com/SimBe195/nvim_config.git

backup() {
	local rel=${1#"$HOME"/}
	mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
	mv "$1" "$BACKUP_DIR/$rel"
	echo "Moved $1 to $BACKUP_DIR/$rel"
}

link_all() {
	while (($# > 0)); do
		mkdir -p "$(dirname "$2")"
		if [[ -e $2 || -L $2 ]]; then
			backup "$2"
		fi
		ln -s "$1" "$2"
		shift 2
	done
}

# plan_links KEY DESCRIPTION SRC DEST [SRC DEST...]: offers to link each DEST that does not already
# point to its SRC.
plan_links() {
	local key=$1 desc=$2 pending=() names=
	shift 2
	while (($# > 0)); do
		if [[ $(readlink "$2") != "$1" ]]; then
			pending+=("$1" "$2")
			names="$names ${2/#$HOME/~}"
		fi
		shift 2
	done
	((${#pending[@]} > 0)) || return 0
	offer "$key" "Link $desc:$names? Existing files are moved to ${BACKUP_DIR/#$HOME/~}." \
		link_all "${pending[@]}"
}

# Links in DIR that point to a file of this repository that no longer exists.
stale_links() {
	local link target
	for link in "$1"/*; do
		[[ -L $link ]] || continue
		target=$(readlink "$link")
		if [[ $target == "$REPO_DIR"/* && ! -e $target ]]; then
			echo "$link"
		fi
	done
}

plan_agent_config() {
	local c=$REPO_DIR/config_files skill stale
	local args=("$c/skills" "$HOME/.agents/skills" "$c/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
		"$c/CLAUDE.md" "$HOME/.codex/AGENTS.md")
	for skill in "$c"/skills/*/; do
		skill=${skill%/}
		args+=("$skill" "$HOME/.claude/skills/${skill##*/}")
	done
	plan_links agent-config "Claude Code and Codex skills and instructions" "${args[@]}"

	stale=$(stale_links "$HOME/.claude/skills")
	if [[ -n $stale ]]; then
		# shellcheck disable=SC2086 # one path per line, none with spaces
		offer stale-skills "Remove links to deleted skills: ${stale//$'\n'/ }?" rm $stale
	fi
}

plan_nvim_config() {
	local dir=$HOME/.config/nvim origin
	origin=$(git -C "$dir" remote get-url origin 2>/dev/null)
	[[ $origin == *github.com[:/]SimBe195/nvim_config* ]] && return
	if [[ -e $dir ]]; then
		offer nvim-config "Replace ~/.config/nvim with a clone of $NVIM_CONFIG_URL? The current one is moved to ${BACKUP_DIR/#$HOME/~}." \
			clone_nvim_config
	else
		offer nvim-config "Clone the Neovim config $NVIM_CONFIG_URL to ~/.config/nvim?" clone_nvim_config
	fi
}

clone_nvim_config() {
	local dir=$HOME/.config/nvim
	if [[ -e $dir ]]; then
		backup "$dir"
	fi
	git clone -q "$NVIM_CONFIG_URL" "$dir"
}

plan_configs() {
	local c=$REPO_DIR/config_files
	if available zsh zsh; then
		plan_links zsh-config "zsh config" "$c/zshrc" "$HOME/.zshrc"
	fi
	# zshrc loads the aliases itself; older setups linked them into oh-my-zsh as well.
	local old_aliases=$HOME/.oh-my-zsh/custom/aliases.zsh
	if [[ $(readlink "$old_aliases") == "$c/aliases.zsh" ]]; then
		offer old-aliases "Remove ${old_aliases/#$HOME/~}? zshrc loads the aliases directly." rm "$old_aliases"
	fi
	if available tmux tmux; then
		plan_links tmux-config "tmux config" "$c/tmux.conf" "$HOME/.tmux.conf"
	fi
	if available starship starship; then
		plan_links starship-config "starship config" "$c/starship.toml" "$HOME/.config/starship.toml"
	fi
	if command -v kitty >/dev/null; then
		plan_links kitty-config "kitty config" "$c/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" \
			"$c/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
	fi
	if available nvim nvim || available nvim nv; then
		plan_nvim_config
	fi
	if available claude claude || available codex codex; then
		plan_agent_config
	fi
}
