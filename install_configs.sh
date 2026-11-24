#!/usr/bin/env bash

# Function to create symlink for configuration files
create_symlink() {
	local install_type=$1
	local SRC=$(realpath $2)
	local DEST=$3

	if [[ $install_type == "yes" ]]; then
		if [[ -L $DEST && $(readlink "$DEST") == "$SRC" ]]; then
			echo "Symlink $DEST is already set up."
			return
		fi
		echo "Creating symlink for $DEST..."
		if [ -e $DEST ]; then
			echo "Destination $DEST already exists. How to proceed?" >&2
			echo " 1) Create backup $DEST.bak and create new symlink" >&2
			echo " 2) Overwrite $DEST and create new symlink" >&2
			echo " 3) Skip" >&2
			echo -n "Select an option: " >&2
			read -r choice
			case $choice in
			1) mv "$DEST" "$DEST.bak" && ln -s $SRC $DEST ;;
			2) rm -rf "$DEST" && ln -s $SRC $DEST ;;
			*) echo "Skipping." ;;
			esac
		else
			ln -s $SRC $DEST
		fi
	else
		echo "Skipping file $SRC"
	fi
}

# Function to clone git repository to location
clone_repo() {
	local install_type=$1
	local REPO=$2
	local DEST=$3

	if [[ $install_type == "yes" ]]; then
		echo "Cloning $REPO to $DEST..."
		if [ -e $DEST ]; then
			echo "Destination $DEST already exists. How to proceed?" >&2
			echo " 1) Create backup $DEST.bak and create new symlink" >&2
			echo " 2) Overwrite $DEST and create new symlink" >&2
			echo " 2) Skip" >&2
			echo -n "Select an option: " >&2
			read -r choice
			case $choice in
			1) mv "$DEST" "$DEST.bak" && git clone $REPO $DEST ;;
			2) rm -rf "$DEST" && git clone $REPO $DEST ;;
			*) echo "Skipping." ;;
			esac
		else
			git clone $REPO $DEST
		fi
	else
		echo "Skipping repo $REPO."
	fi
}

# Symlink configuration files based on installation choices
BASE_DIR=$(dirname "$(readlink -f "$0")")
echo $BASE_DIR

create_symlink $INSTALL_ZSH_CONFIG $BASE_DIR/config_files/zshrc $HOME/.zshrc
create_symlink $INSTALL_ZSH_CONFIG $BASE_DIR/config_files/aliases.zsh $HOME/.oh-my-zsh/custom/aliases.zsh
create_symlink $INSTALL_TMUX_CONFIG $BASE_DIR/config_files/tmux.conf $HOME/.tmux.conf
clone_repo $INSTALL_NVIM_CONFIG "https://github.com/SimBe195/AstroNvimConfig.git" $HOME/.config/nvim
create_symlink $INSTALL_STARSHIP_CONFIG $BASE_DIR/config_files/starship.toml $HOME/.config/starship.toml

# Codex reads skills from ~/.agents/skills, Claude Code only from ~/.claude/skills. ~/.claude/skills
# also holds skills synced from claude.ai, so it gets one link per skill instead of a directory link.
if [[ $INSTALL_AGENT_CONFIG == "yes" ]]; then
	mkdir -p $HOME/.agents $HOME/.claude/skills $HOME/.codex
fi
create_symlink $INSTALL_AGENT_CONFIG $BASE_DIR/config_files/skills $HOME/.agents/skills
for skill in $BASE_DIR/config_files/skills/*/; do
	create_symlink $INSTALL_AGENT_CONFIG $skill $HOME/.claude/skills/$(basename $skill)
done
create_symlink $INSTALL_AGENT_CONFIG $BASE_DIR/config_files/CLAUDE.md $HOME/.claude/CLAUDE.md
create_symlink $INSTALL_AGENT_CONFIG $BASE_DIR/config_files/CLAUDE.md $HOME/.codex/AGENTS.md

echo ""
echo "===================================="
echo "All configurations have been set up."
echo "===================================="
