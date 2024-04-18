#!/usr/bin/env bash

# Function to ask for installation preference
ask_install() {
	# Clear buffer and display message, flush using stdout redirect
	echo "$1:" >&2
	echo " 1) Yes" >&2
	echo " 2) No" >&2
	echo -n "Select an option: " >&2
	read -r choice
	case $choice in
	1) echo "yes" ;;
	*) echo "no" ;;
	esac
}

# Ask for each installation
# Export variables for sub-scripts to use
if [ "$(uname)" == "Darwin" ] && ! command -v brew &>/dev/null; then
	export INSTALL_HOMEBREW=$(ask_install "Install Homebrew package manager")
fi

if ! command -v nala &>/dev/null && ! command -v apt &>/dev/null; then
	export INSTALL_NALA=$(ask_install "Install nala as apt replacement (requires sudo privileges)")
else
	export INSTALL_NALA=no
fi

if ! command -v zsh &>/dev/null; then
	export INSTALL_ZSH=$(ask_install "Install zsh (requires sudo privileges)")
else
	export INSTALL_ZSH=no
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
	export INSTALL_OHMYZSH=$(ask_install "Install oh-my-zsh")
else
	export INSTALL_OHMYZSH=no
fi

if [ ! -f "$HOME/.oh-my-zsh/custom/catppuccin_mocha-zsh-syntax-highlighting.zsh" ]; then
	export INSTALL_CATPPUCCIN_ZSH=$(ask_install "Install catppuccin zsh-syntax-highlighting theme")
else
	export INSTALL_CATPPUCCIN_ZSH=no
fi

if ! command -v tmux &>/dev/null; then
	export INSTALL_TMUX=$(ask_install "Install tmux (requires sudo privileges)")
else
	export INSTALL_TMUX=no
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
	export INSTALL_TPM=$(ask_install "Install tmux package manager (TPM)")
else
	export INSTALL_TPM=no
fi

if ! command -v starship &>/dev/null; then
	export INSTALL_STARSHIP=$(ask_install "Install starship prompt")
else
	export INSTALL_STARSHIP=no
fi

if ! command -v nv &>/dev/null; then
	export INSTALL_NVIM=$(ask_install "Install NeoVim")
else
	export INSTALL_NVIM=no
fi

if ! command -v cargo &>/dev/null; then
	export INSTALL_CARGO=$(ask_install "Install cargo")
else
	export INSTALL_CARGO=no
fi

if ! command -v node &>/dev/null; then
	export INSTALL_NODE=$(ask_install "Install Node.js")
else
	export INSTALL_NODE=no
fi

if ! command -v tldr &>/dev/null; then
	export INSTALL_TLDR=$(ask_install "Install tldr man pages replacement")
else
	export INSTALL_TLDR=no
fi

if ! command -v lazygit &>/dev/null; then
	export INSTALL_LAZYGIT=$(ask_install "Install lazygit")
else
	export INSTALL_LAZYGIT=no
fi

if ! command -v gdu &>/dev/null; then
	export INSTALL_GDU=$(ask_install "Install GDU disk usage analyzer")
else
	export INSTALL_GDU=no
fi

if ! command -v btm &>/dev/null; then
	export INSTALL_BOTTOM=$(ask_install "Install bottom system monitor")
else
	export INSTALL_BOTTOM=no
fi

if ! command -v rg &>/dev/null; then
	export INSTALL_RG=$(ask_install "Install ripgrep")
else
	export INSTALL_RG=no
fi

if ! command -v tree-sitter &>/dev/null; then
	export INSTALL_TS=$(ask_install "Install tree-sitter CLI")
else
	export INSTALL_TS=no
fi

export INSTALL_ZSH_CONFIG=$(ask_install "Install zsh config")
export INSTALL_TMUX_CONFIG=$(ask_install "Install tmux config")
export INSTALL_NVIM_CONFIG=$(ask_install "Install Neovim config")
export INSTALL_STARSHIP_CONFIG=$(ask_install "Install starship prompt config")

# Call installation sub-scripts
BASE_DIR=$(dirname "$(readlink -f "%0")")

$BASE_DIR/install_configs.sh
$BASE_DIR/install_software.sh
